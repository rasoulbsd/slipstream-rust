# Subdomain Length Limit

## Problem

The Great Firewall (GFW) in Iran and other censored regions limits the total subdomain length in DNS queries. According to testing:

- **Subdomains with 102+ characters**: Blocked by GFW, don't reach the server
- **Subdomains with ≤101 characters**: Pass through GFW successfully

This affects DNS tunneling protocols that encode data in subdomains, including slipstream-rust.

## Solution

The `--max-subdomain-length` option allows you to limit the subdomain length to ensure queries pass through GFW restrictions.

## Usage

### Client

```bash
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com \
    --max-subdomain-length 101
```

### Recommended Values

- **Iran (GFW)**: `101` characters
- **Other regions**: Test to find optimal value, or omit for unlimited (default)

## How It Works

1. **Payload Encoding**: QUIC packets are base32-encoded and then "dotted" (dots inserted every 57 characters)
2. **Length Calculation**: The subdomain length is the base32-encoded, dotted string length
3. **Limit Enforcement**: When `--max-subdomain-length` is set, the client:
   - Calculates the maximum payload size that fits within the limit
   - Ensures all generated subdomains respect the limit
   - Splits larger payloads across multiple DNS queries if needed

## Example

Without limit (may be blocked):
```
OXNWZGDTUGNGFBUALMDSYTLGAU6B5Z4XPJBXWUJHIYBBWL6MNZSVLMVEX.DYYJQ2LODHWG3JIBKHBTLLYVPP.abc.aaaaaaaaaa.ir
(102 characters - BLOCKED)
```

With `--max-subdomain-length 101`:
```
OXNWZGDTUGNGFBUALMDSYTLGAU6B5Z4XPJBXWUJHIYBBWL6MNZSVLMVEX.DYYJQ2LODHWG3JIBKHBTLLYVP.abc.aaaaaaaaaa.ir
(101 characters - PASSES)
```

## Impact on Performance

Limiting subdomain length reduces the payload size per DNS query:
- **More DNS queries** needed for the same data
- **Slightly slower** transfer speeds
- **Better compatibility** with censored networks

The trade-off is necessary for regions where DNS tunneling is the only available method.

## Testing

To verify the limit is working:

1. **Check subdomain length**:
   ```bash
   # Monitor DNS queries
   sudo tcpdump -i any -n port 53 | grep your-domain.com
   
   # Extract and measure subdomain lengths
   ```

2. **Compare with/without limit**:
   ```bash
   # Without limit (may fail in GFW regions)
   ./slipstream-client --domain example.com ...
   
   # With limit (should work)
   ./slipstream-client --domain example.com --max-subdomain-length 101 ...
   ```

3. **Monitor connection success rate**:
   - Without limit: High failure rate in GFW regions
   - With limit: Improved success rate

## Technical Details

### Base32 Encoding
- Each byte requires ~1.6 base32 characters (5 bits per char, 8 bits per byte)
- Example: 63 bytes → ~101 base32 characters

### Dot Insertion
- Dots are inserted every 57 characters to keep DNS labels ≤57 chars
- This adds to the total subdomain length
- Example: 101 base32 chars → 101 chars (no dots needed if ≤57)

### Payload Calculation
The maximum payload size is calculated as:
1. Start with max subdomain length (e.g., 101)
2. Account for dots (every 57 chars)
3. Calculate max base32 length
4. Convert to payload bytes: `(base32_len * 5) / 8`

## Related Features

- **Case Normalization** (`--normalize-case`): Handles GFW case randomization
- **MTU Configuration** (`--mtu`): Controls QUIC packet size
- **Subdomain Length Limit** (`--max-subdomain-length`): Controls DNS query size

Use all three features together for maximum compatibility in censored regions.
