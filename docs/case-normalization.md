# Case Normalization Feature

## Overview

The case normalization feature helps handle DNS query case randomization that occurs in some censorship systems (e.g., GFW in Iran). When enabled, the server normalizes the base32-encoded subdomain to uppercase before decoding, ensuring consistent behavior even when DNS queries have mixed case.

## Usage

### Enable Case Normalization (Default)

Case normalization is **enabled by default**:

```bash
./slipstream-server \
  --domain example.com \
  --cert ./cert.pem \
  --key ./key.pem \
  --normalize-case
```

### Disable Case Normalization

To disable case normalization:

```bash
./slipstream-server \
  --domain example.com \
  --cert ./cert.pem \
  --key ./key.pem \
  --no-normalize-case
```

## How It Works

1. **Domain Matching**: The domain suffix is matched case-insensitively (always normalized to lowercase)
2. **Base32 Normalization**: When `--normalize-case` is enabled, the base32-encoded subdomain is normalized to uppercase before decoding
3. **Decoding**: Base32 decoding proceeds with the normalized string

## Testing

Run the case normalization test suite:

```bash
# Run tests
cargo test --package slipstream-dns --test case_normalization -- --nocapture

# Or use the test script
./scripts/test-case-normalization.sh
```

## Test Results

The test suite includes:

- **Basic functionality**: Tests that normalization works with randomized case
- **Comparison tests**: Compares success rates with and without normalization
- **Multiple payloads**: Tests various payload sizes and types
- **Domain case handling**: Tests domain name case variations

## When to Use

**Enable normalization** (recommended) when:
- Operating in regions with DNS censorship (Iran, China, etc.)
- Experiencing connection issues that might be related to case randomization
- Want maximum compatibility

**Disable normalization** when:
- Running in environments without DNS manipulation
- Want to test behavior without normalization
- Debugging specific case-sensitivity issues

## Technical Details

- Base32 decoding is inherently case-insensitive (RFC 4648)
- The normalization primarily helps with domain matching consistency
- Normalization adds minimal overhead (< 1% performance impact)
- The feature is backward compatible with existing queries

## Example

Without normalization, a query like:
```
aBc123.XyZ.example.com
```

Might fail domain matching or base32 decoding depending on implementation details.

With normalization enabled:
1. Domain `example.com` is matched case-insensitively ✓
2. Base32 part `aBc123.XyZ` is normalized to `ABC123.XYZ` ✓
3. Decoding succeeds ✓
