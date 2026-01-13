use slipstream_dns::{
    decode_query, decode_query_with_case_normalization, encode_query, DecodeQueryError, QueryParams,
    CLASS_IN, RR_TXT,
};

/// Helper function to randomize case of a string (simulating GFW behavior)
fn randomize_case(input: &str) -> String {
    let mut result = String::with_capacity(input.len());
    for (i, ch) in input.chars().enumerate() {
        if ch.is_ascii_alphabetic() {
            // Use position and character code to deterministically randomize case
            let code = ch as u8;
            if (i as u8 + code) % 2 == 0 {
                result.push(ch.to_ascii_uppercase());
            } else {
                result.push(ch.to_ascii_lowercase());
            }
        } else {
            result.push(ch);
        }
    }
    result
}

/// Helper function to randomize case more aggressively (simulating GFW)
fn aggressive_randomize_case(input: &str) -> String {
    input
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphabetic() {
                // More aggressive randomization
                if (ch as u8) % 3 == 0 {
                    ch.to_ascii_uppercase()
                } else if (ch as u8) % 3 == 1 {
                    ch.to_ascii_lowercase()
                } else {
                    // Keep original case sometimes
                    ch
                }
            } else {
                ch
            }
        })
        .collect()
}

/// Create a DNS query packet with randomized case in the QNAME
fn create_query_with_randomized_case(payload: &[u8], domain: &str, randomize: bool) -> Vec<u8> {
    use slipstream_dns::{build_qname, encode_query, QueryParams, CLASS_IN, RR_TXT};
    
    let qname = build_qname(payload, domain).expect("build qname");
    let qname_final = if randomize {
        // Randomize case in the subdomain part (before the domain)
        let domain_suffix = format!(".{}.", domain);
        if let Some(subdomain_end) = qname.rfind(&domain_suffix) {
            let subdomain = &qname[..subdomain_end];
            let randomized_subdomain = aggressive_randomize_case(subdomain);
            format!("{}{}", randomized_subdomain, domain_suffix)
        } else {
            aggressive_randomize_case(&qname)
        }
    } else {
        qname
    };
    
    encode_query(&QueryParams {
        id: 0x1234,
        qname: &qname_final,
        qtype: RR_TXT,
        qclass: CLASS_IN,
        rd: true,
        cd: false,
        qdcount: 1,
        is_query: true,
    })
    .expect("encode query")
}

#[test]
fn test_case_normalization_enabled() {
    let domain = "example.com";
    let payload = b"Hello, World!";
    
    // Create query with randomized case
    let query_packet = create_query_with_randomized_case(payload, domain, true);
    
    // Decode with normalization enabled (should succeed)
    match decode_query_with_case_normalization(&query_packet, domain, true) {
        Ok(decoded) => {
            assert_eq!(decoded.payload, payload);
            println!("✓ Case normalization enabled: SUCCESS");
        }
        Err(e) => {
            panic!("Case normalization enabled should succeed, got: {:?}", e);
        }
    }
}

#[test]
fn test_case_normalization_disabled() {
    let domain = "example.com";
    let payload = b"Hello, World!";
    
    // Create query with randomized case
    let query_packet = create_query_with_randomized_case(payload, domain, true);
    
    // Decode with normalization disabled (may fail if case matters)
    match decode_query_with_case_normalization(&query_packet, domain, false) {
        Ok(decoded) => {
            // Base32 decode is case-insensitive, so it might still work
            assert_eq!(decoded.payload, payload);
            println!("✓ Case normalization disabled: Still works (base32 is case-insensitive)");
        }
        Err(e) => {
            println!("⚠ Case normalization disabled: Failed (expected if domain matching is strict): {:?}", e);
        }
    }
}

#[test]
fn test_normal_query_without_randomization() {
    let domain = "example.com";
    let payload = b"Test payload";
    
    // Create normal query without randomization
    let query_packet = create_query_with_randomized_case(payload, domain, false);
    
    // Should work with both enabled and disabled normalization
    let decoded_enabled = decode_query_with_case_normalization(&query_packet, domain, true)
        .expect("decode with normalization enabled");
    let decoded_disabled = decode_query_with_case_normalization(&query_packet, domain, false)
        .expect("decode with normalization disabled");
    
    assert_eq!(decoded_enabled.payload, payload);
    assert_eq!(decoded_disabled.payload, payload);
    println!("✓ Normal query works with both normalization settings");
}

#[test]
fn test_multiple_randomized_queries() {
    let domain = "test.example.com";
    let payloads = vec![
        b"Payload 1".to_vec(),
        b"Payload 2".to_vec(),
        b"Longer payload with more data".to_vec(),
        b"X".to_vec(),
    ];
    
    let mut success_count = 0;
    let mut total_tests = 0;
    
    for payload in &payloads {
        total_tests += 1;
        let query_packet = create_query_with_randomized_case(payload, domain, true);
        
        match decode_query_with_case_normalization(&query_packet, domain, true) {
            Ok(decoded) => {
                if decoded.payload == *payload {
                    success_count += 1;
                } else {
                    eprintln!("Payload mismatch for {:?}", payload);
                }
            }
            Err(e) => {
                eprintln!("Failed to decode {:?}: {:?}", payload, e);
            }
        }
    }
    
    let success_rate = (success_count as f64 / total_tests as f64) * 100.0;
    println!("✓ Randomized queries: {}/{} succeeded ({:.1}%)", success_count, total_tests, success_rate);
    
    // Should succeed for all queries with normalization enabled
    assert_eq!(success_count, total_tests, "All randomized queries should succeed with normalization");
}

#[test]
fn test_domain_case_randomization() {
    let domain = "Example.COM"; // Mixed case domain
    let payload = b"Test";
    
    // Create query
    let qname = slipstream_dns::build_qname(payload, domain).expect("build qname");
    let query_packet = encode_query(&QueryParams {
        id: 0x1234,
        qname: &qname,
        qtype: RR_TXT,
        qclass: CLASS_IN,
        rd: true,
        cd: false,
        qdcount: 1,
        is_query: true,
    })
    .expect("encode query");
    
    // Should work with normalization (domain matching is case-insensitive)
    let decoded = decode_query_with_case_normalization(&query_packet, domain, true)
        .expect("decode should succeed");
    assert_eq!(decoded.payload, payload);
    
    // Also test with lowercase domain
    let decoded_lower = decode_query_with_case_normalization(&query_packet, "example.com", true)
        .expect("decode should succeed");
    assert_eq!(decoded_lower.payload, payload);
    
    println!("✓ Domain case randomization handled correctly");
}

#[test]
fn test_comparison_with_without_normalization() {
    let domain = "example.com";
    let payload = b"Comparison test";
    
    // Create multiple randomized queries
    let mut success_with = 0;
    let mut success_without = 0;
    let iterations = 10;
    
    for _ in 0..iterations {
        let query_packet = create_query_with_randomized_case(payload, domain, true);
        
        // Test with normalization
        if decode_query_with_case_normalization(&query_packet, domain, true)
            .map(|d| d.payload == payload)
            .unwrap_or(false)
        {
            success_with += 1;
        }
        
        // Test without normalization
        if decode_query_with_case_normalization(&query_packet, domain, false)
            .map(|d| d.payload == payload)
            .unwrap_or(false)
        {
            success_without += 1;
        }
    }
    
    println!("✓ Comparison test:");
    println!("  With normalization: {}/{} ({:.1}%)", success_with, iterations, (success_with as f64 / iterations as f64) * 100.0);
    println!("  Without normalization: {}/{} ({:.1}%)", success_without, iterations, (success_without as f64 / iterations as f64) * 100.0);
    
    // With normalization should be more reliable
    assert!(success_with >= success_without, "Normalization should improve success rate");
}
