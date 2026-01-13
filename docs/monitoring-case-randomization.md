# Monitoring Case Randomization

This guide explains how to detect and monitor DNS query case randomization, which can break slipstream connections in censored environments.

## Quick Detection

### 1. Quick Check Script

```bash
# Detect case randomization in live traffic
./scripts/detect-case-randomization.sh example.com live

# Or analyze from a log file
./scripts/detect-case-randomization.sh example.com file dns-queries.log
```

### 2. Python Monitor (Detailed Analysis)

```bash
# Monitor for 60 seconds
python3 scripts/monitor-case-randomization.py \
    --domain example.com \
    --interface any \
    --duration 60

# Or analyze from file
python3 scripts/monitor-case-randomization.py \
    --domain example.com \
    --file dns-queries.txt
```

### 3. Bash Monitor (Simple)

```bash
# Monitor for 5 minutes
sudo ./scripts/monitor-dns-queries.sh example.com any 300
```

## Testing Normalization Effectiveness

### Compare With/Without Normalization

```bash
# Run comparison test
./scripts/compare-normalization.sh

# Or set custom parameters
DOMAIN=your-domain.com SERVER_PORT=53 TEST_DURATION=120 \
    ./scripts/compare-normalization.sh
```

### Live Test

```bash
# Test with randomized queries
./scripts/test-case-normalization-live.sh
```

## Manual Testing

### 1. Capture DNS Queries

```bash
# Capture DNS traffic
sudo tcpdump -i any -n -l "udp port 53" > dns-capture.txt

# In another terminal, generate traffic
# (use your slipstream client or send test queries)
```

### 2. Analyze Captured Queries

```bash
# Extract query names
grep -oE '[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+' dns-capture.txt | \
    grep your-domain.com | \
    sort -u > queries.txt

# Analyze
python3 scripts/monitor-case-randomization.py \
    --domain your-domain.com \
    --file queries.txt
```

### 3. Check Server Logs

Enable debug logging on the server:

```bash
./slipstream-server \
    --domain example.com \
    --cert cert.pem \
    --key key.pem \
    --debug-streams \
    --normalize-case
```

Look for:
- `ServerFailure` responses (might indicate base32 decode failures)
- Connection drops
- Failed QUIC packet processing

## Production Monitoring

### 1. Log DNS Query Patterns

Add logging to capture query names:

```bash
# Monitor server logs for patterns
tail -f server.log | grep -E "(qname|query|decode)" | \
    awk '{print $NF}' | \
    sort | uniq -c | sort -rn
```

### 2. Track Success Rates

Monitor connection success rates:

```bash
# Count successful vs failed connections
grep -c "Connection ready" client.log
grep -c "decode failed\|ServerFailure" server.log
```

### 3. Compare Metrics

Run A/B test:

```bash
# Test period 1: With normalization
./slipstream-server --normalize-case ... &
# Monitor for 1 hour
# Record success rate

# Test period 2: Without normalization  
./slipstream-server --no-normalize-case ... &
# Monitor for 1 hour
# Record success rate

# Compare results
```

## Indicators of Case Randomization

Look for these patterns:

1. **Mixed case in subdomain**: `AbC123.XyZ.example.com`
2. **Inconsistent case patterns**: Some queries uppercase, some lowercase
3. **Base32 decode failures**: Server logs show `ServerFailure` responses
4. **Connection drops**: Client can't establish connection
5. **High error rate**: Many failed DNS queries

## Expected Results

### Without Case Randomization
- All queries have consistent case (usually all uppercase for base32)
- High success rate (>95%)
- No decode errors

### With Case Randomization (GFW)
- Mixed case in queries
- Lower success rate without normalization
- Improved success rate with normalization enabled

## Troubleshooting

### If normalization doesn't help:

1. **Check if case randomization is actually happening**:
   ```bash
   ./scripts/detect-case-randomization.sh your-domain.com live
   ```

2. **Verify normalization is enabled**:
   ```bash
   ./slipstream-server --help | grep normalize
   ```

3. **Check server logs for other errors**:
   - Certificate issues
   - Network problems
   - QUIC context creation failures

### If you see mixed case but normalization doesn't help:

1. The issue might be elsewhere (network, certificates, etc.)
2. Case randomization might be more complex than simple case changes
3. Check if the domain matching is working correctly

## Continuous Monitoring

Set up automated monitoring:

```bash
# Add to cron (runs every hour)
0 * * * * /path/to/scripts/detect-case-randomization.sh your-domain.com live >> /var/log/dns-case-monitor.log 2>&1

# Alert if randomization detected
if grep -q "CASE RANDOMIZATION DETECTED" /var/log/dns-case-monitor.log; then
    # Send alert (email, webhook, etc.)
fi
```

## Metrics to Track

1. **Case pattern distribution**:
   - Percentage of mixed-case queries
   - Percentage of all-uppercase queries
   - Percentage of all-lowercase queries

2. **Success rates**:
   - Connection success rate
   - Query decode success rate
   - QUIC packet processing success rate

3. **Error patterns**:
   - `ServerFailure` response rate
   - Base32 decode error rate
   - Domain matching failures

## Example Output

```
=== Case Randomization Detector ===
Domain: example.com
Mode: live

⚠ Mixed case detected: AbC123.XyZ.example.com
⚠ Mixed case detected: DeF456.GhI.example.com

=== Analysis ===
Total queries analyzed: 50
Mixed case queries: 12
Mixed case percentage: 24%

🚨 CASE RANDOMIZATION DETECTED!

Recommendation:
  Enable case normalization on your server:
    ./slipstream-server --domain example.com --normalize-case ...
```
