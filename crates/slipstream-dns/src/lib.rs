mod base32;
mod dns;
mod dots;

pub use base32::{decode as base32_decode, encode as base32_encode, Base32Error};
pub use dns::{
    decode_query, decode_query_with_case_normalization, decode_response, encode_query,
    encode_response, DecodeQueryError, DecodedQuery, DnsError, QueryParams, Question, Rcode,
    ResponseParams, CLASS_IN, EDNS_UDP_PAYLOAD, RR_A, RR_OPT, RR_TXT,
};
pub use dots::{dotify, undotify};

pub fn build_qname(payload: &[u8], domain: &str) -> Result<String, DnsError> {
    build_qname_with_max_subdomain_length(payload, domain, None)
}

pub fn build_qname_with_max_subdomain_length(
    payload: &[u8],
    domain: &str,
    max_subdomain_length: Option<usize>,
) -> Result<String, DnsError> {
    let domain = domain.trim_end_matches('.');
    if domain.is_empty() {
        return Err(DnsError::new("domain must not be empty"));
    }
    let max_payload = max_payload_len_for_domain_with_max_subdomain(domain, max_subdomain_length)?;
    if payload.len() > max_payload {
        return Err(DnsError::new("payload too large for domain"));
    }
    let base32 = base32_encode(payload);
    let dotted = dotify(&base32);
    let subdomain_len = dotted.len();
    if let Some(max_len) = max_subdomain_length {
        if subdomain_len > max_len {
            return Err(DnsError::new(format!(
                "subdomain length {} exceeds maximum {}",
                subdomain_len, max_len
            )));
        }
    }
    Ok(format!("{}.{}.", dotted, domain))
}

pub fn max_payload_len_for_domain(domain: &str) -> Result<usize, DnsError> {
    max_payload_len_for_domain_with_max_subdomain(domain, None)
}

pub fn max_payload_len_for_domain_with_max_subdomain(
    domain: &str,
    max_subdomain_length: Option<usize>,
) -> Result<usize, DnsError> {
    let domain = domain.trim_end_matches('.');
    if domain.is_empty() {
        return Err(DnsError::new("domain must not be empty"));
    }
    if domain.len() > dns::MAX_DNS_NAME_LEN {
        return Err(DnsError::new("domain too long"));
    }
    
    // If max_subdomain_length is specified, use it; otherwise use DNS name limit
    let max_dotted_len = if let Some(max_subdomain) = max_subdomain_length {
        max_subdomain
    } else {
        let max_name_len = dns::MAX_DNS_NAME_LEN;
        max_name_len.saturating_sub(domain.len() + 1)
    };
    
    if max_dotted_len == 0 {
        return Ok(0);
    }
    
    // Calculate maximum base32 length that fits within max_dotted_len
    // Accounting for dots inserted every 57 characters
    let mut max_base32_len = 0usize;
    for len in 1..=max_dotted_len {
        let dots = (len - 1) / 57;
        if len + dots > max_dotted_len {
            break;
        }
        max_base32_len = len;
    }

    // Convert base32 length to payload length (base32 is 5 bits per char, payload is 8 bits per byte)
    let mut max_payload = (max_base32_len * 5) / 8;
    // Ensure the base32 encoding of max_payload doesn't exceed max_base32_len
    while max_payload > 0 && base32_len(max_payload) > max_base32_len {
        max_payload -= 1;
    }
    Ok(max_payload)
}

fn base32_len(payload_len: usize) -> usize {
    if payload_len == 0 {
        return 0;
    }
    (payload_len * 8).div_ceil(5)
}

#[cfg(test)]
mod tests {
    use super::{build_qname, build_qname_with_max_subdomain_length, max_payload_len_for_domain, max_payload_len_for_domain_with_max_subdomain};

    #[test]
    fn build_qname_rejects_payload_overflow() {
        let domain = "test.com";
        let max_payload = max_payload_len_for_domain(domain).expect("max payload");
        let payload = vec![0u8; max_payload + 1];
        assert!(build_qname(&payload, domain).is_err());
    }

    #[test]
    fn build_qname_rejects_long_domain() {
        let domain = format!("{}.com", "a".repeat(260));
        let payload = vec![0u8; 1];
        assert!(build_qname(&payload, &domain).is_err());
    }

    #[test]
    fn max_subdomain_length_limits_payload() {
        let domain = "example.com";
        // Without limit, should allow larger payload
        let max_unlimited = max_payload_len_for_domain(domain).expect("max payload");
        
        // With 101 char limit (GFW limit), should be more restrictive
        let max_limited = max_payload_len_for_domain_with_max_subdomain(domain, Some(101))
            .expect("max payload with limit");
        
        assert!(max_limited <= max_unlimited, "Limited max should be <= unlimited");
        
        // Test that build_qname respects the limit
        let payload = vec![0u8; max_limited];
        let result = build_qname_with_max_subdomain_length(&payload, domain, Some(101));
        assert!(result.is_ok(), "Should succeed with payload at limit");
        
        // Test that exceeding limit fails
        if max_limited > 0 {
            let payload_too_large = vec![0u8; max_limited + 1];
            let result = build_qname_with_max_subdomain_length(&payload_too_large, domain, Some(101));
            // This might fail due to payload size or subdomain length, both are valid
            assert!(result.is_err(), "Should fail when exceeding limit");
        }
    }

    #[test]
    fn build_qname_respects_subdomain_length_limit() {
        let domain = "test.com";
        // Create a payload that would produce a subdomain > 101 chars
        // Base32 encoding: each byte becomes ~1.6 chars
        // So ~63 bytes should produce ~101 base32 chars
        let payload = vec![0u8; 63];
        let result = build_qname_with_max_subdomain_length(&payload, domain, Some(101));
        // Should either succeed (if it fits) or fail gracefully
        match result {
            Ok(qname) => {
                // Extract subdomain (everything before the domain)
                let subdomain = qname.strip_suffix(&format!(".{}.", domain)).unwrap();
                assert!(subdomain.len() <= 101, "Subdomain should respect limit");
            }
            Err(_) => {
                // Failure is acceptable if payload is too large
            }
        }
    }
}
