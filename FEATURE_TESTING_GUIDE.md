# Feature Testing Guide

## New Features Summary

### 1. Case Normalization (`--normalize-case`)
- **Purpose**: Handles DNS query case randomization from censorship systems (GFW)
- **Default**: Enabled
- **Flag**: `--normalize-case` (default) or `--no-normalize-case` to disable

### 2. Configurable MTU (`--mtu`)
- **Purpose**: Override MTU size for QUIC packets
- **Server**: `--mtu <value>` (default: 900)
- **Client**: `--mtu <value>` (default: computed from domain length)

### 3. Subdomain Length Limit (`--max-subdomain-length`)
- **Purpose**: Limit subdomain length to bypass GFW restrictions
- **Client**: `--max-subdomain-length <value>` (recommended: 101 for Iran)
- **When to use**: In regions where GFW blocks long subdomains (>101 chars)

## Quick Start Testing

### Step 1: Verify the Problem Exists

**Test WITHOUT case normalization** to see if the problem occurs:

```bash
# Start server WITHOUT normalization
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --no-normalize-case \
    --debug-streams

# In another terminal, start client
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com

# Try to connect and observe errors
```

**What to look for:**
- `ServerFailure` responses in server logs
- Base32 decode errors
- Connection failures
- Mixed-case DNS queries in network captures

### Step 2: Detect Case Randomization

```bash
# Quick detection (30 seconds)
./scripts/detect-case-randomization.sh your-domain.com live

# If it shows "CASE RANDOMIZATION DETECTED", the problem exists
```

### Step 3: Test WITH Normalization

```bash
# Start server WITH normalization (default)
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --normalize-case \
    --debug-streams

# Same client setup
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com

# Compare results - should see fewer errors
```

## Complete Testing Procedure

### Phase 1: Baseline Measurement (Without Fix)

**1.1 Start server without normalization:**
```bash
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --no-normalize-case \
    --debug-streams \
    --mtu 900 \
    > server-baseline.log 2>&1
```

**1.2 Start client:**
```bash
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com \
    > client-baseline.log 2>&1
```

**1.3 Generate test traffic:**
```bash
# Send test data
echo "test data" | nc 127.0.0.1 7000

# Or use SSH
ssh -p 7000 user@127.0.0.1
```

**1.4 Collect metrics (run for 10-15 minutes):**
```bash
# Count errors
grep -c "ServerFailure" server-baseline.log
grep -c "decode failed" server-baseline.log
grep -c "Connection ready" client-baseline.log
grep -c "Connection closed" client-baseline.log

# Monitor DNS queries
sudo ./scripts/monitor-dns-queries.sh your-domain.com any 600
```

**1.5 Record results:**
- Total queries sent
- Successful connections
- Failed connections
- Error types and counts

### Phase 2: Test With Normalization

**2.1 Start server with normalization:**
```bash
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --normalize-case \
    --debug-streams \
    --mtu 900 \
    > server-normalized.log 2>&1
```

**2.2 Use same client setup:**
```bash
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com \
    > client-normalized.log 2>&1
```

**2.3 Generate same test traffic:**
```bash
# Same tests as Phase 1
echo "test data" | nc 127.0.0.1 7000
```

**2.4 Collect same metrics (same duration):**
```bash
# Count errors
grep -c "ServerFailure" server-normalized.log
grep -c "decode failed" server-normalized.log
grep -c "Connection ready" client-normalized.log
grep -c "Connection closed" client-normalized.log
```

### Phase 3: Comparison and Analysis

**3.1 Compare metrics:**
```bash
echo "=== Baseline (without normalization) ==="
echo "Errors: $(grep -c 'ServerFailure' server-baseline.log)"
echo "Success: $(grep -c 'Connection ready' client-baseline.log)"

echo ""
echo "=== With Normalization ==="
echo "Errors: $(grep -c 'ServerFailure' server-normalized.log)"
echo "Success: $(grep -c 'Connection ready' client-normalized.log)"
```

**3.2 Automated comparison:**
```bash
./scripts/compare-normalization.sh
```

**3.3 Analyze DNS patterns:**
```bash
# Check if case randomization was detected
python3 scripts/monitor-case-randomization.py \
    --domain your-domain.com \
    --file dns-queries.log
```

## Validating the Fix Works

### Test 1: Unit Tests

```bash
# Run case normalization tests
cargo test --package slipstream-dns --test case_normalization -- --nocapture

# Expected: All tests pass
```

### Test 2: Simulated Case Randomization

```bash
# Run test suite that simulates GFW behavior
./scripts/test-case-normalization.sh

# Expected: 
# - With normalization: 100% success
# - Without normalization: Lower success rate
```

### Test 3: Real-World Test

**Prerequisites:**
- Server in censored region (Iran, etc.)
- Client outside censored region
- Domain configured properly

**Steps:**
1. Start server with normalization
2. Start client
3. Monitor for 1 hour
4. Compare with previous runs without normalization

**Success criteria:**
- Higher connection success rate
- Fewer decode errors
- More stable connections

## MTU Testing

### Test Different MTU Values

```bash
# Test with smaller MTU
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --mtu 500

# Test with larger MTU
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --mtu 1200

# Client can also override
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com \
    --mtu 800
```

### MTU Considerations

- **Smaller MTU**: More DNS queries, potentially slower but more compatible
- **Larger MTU**: Fewer queries, faster but may hit DNS size limits
- **Default**: Server 900, Client computed from domain length

## Complete Test Checklist

### Pre-Test Setup
- [ ] Server certificates generated
- [ ] Domain configured
- [ ] Network connectivity verified
- [ ] Monitoring tools ready

### Problem Verification (Without Fix)
- [ ] Server started with `--no-normalize-case`
- [ ] Client connected
- [ ] Case randomization detected (if applicable)
- [ ] Errors observed and logged
- [ ] Metrics collected (10-15 minutes)

### Fix Validation (With Normalization)
- [ ] Server started with `--normalize-case`
- [ ] Client connected
- [ ] Same test traffic generated
- [ ] Metrics collected (same duration)
- [ ] Results compared

### Analysis
- [ ] Success rate improved
- [ ] Error count reduced
- [ ] Connection stability improved
- [ ] Case randomization handled correctly

## Example Test Session

```bash
# 1. Detect problem
$ ./scripts/detect-case-randomization.sh example.com live
⚠ Mixed case detected: AbC123.example.com
🚨 CASE RANDOMIZATION DETECTED!

# 2. Baseline test (without fix)
$ ./slipstream-server --no-normalize-case --domain example.com ...
# Monitor for 10 minutes
# Result: 72% success rate, 28 errors

# 3. Test with fix
$ ./slipstream-server --normalize-case --domain example.com ...
# Monitor for 10 minutes  
# Result: 95% success rate, 5 errors

# 4. Comparison
$ ./scripts/compare-normalization.sh
=== Summary ===
With normalization: 95/100 (95%)
Without normalization: 72/100 (72%)
✓ Improvement: 23 queries (32% better)
```

## Troubleshooting

### If normalization doesn't help:

1. **Verify it's actually case randomization:**
   ```bash
   ./scripts/detect-case-randomization.sh your-domain.com live
   ```

2. **Check other issues:**
   - Network connectivity
   - Certificate problems
   - DNS resolver issues
   - Firewall blocking

3. **Verify normalization is enabled:**
   ```bash
   ./slipstream-server --help | grep normalize
   ```

### If tests fail:

1. **Check prerequisites:**
   - Certificates exist and are valid
   - Domain is correct
   - Network is accessible

2. **Run unit tests:**
   ```bash
   cargo test --package slipstream-dns --test case_normalization
   ```

3. **Check logs:**
   ```bash
   tail -f server.log | grep -E "(error|Error|failed|Failed)"
   ```

## Production Deployment

### Recommended Configuration

```bash
# Server (with all features)
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --normalize-case \
    --mtu 900 \
    --debug-streams

# Client (for GFW regions like Iran)
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com \
    --normalize-case \
    --max-subdomain-length 101
```

### Monitoring in Production

```bash
# Continuous monitoring
0 * * * * /path/to/scripts/detect-case-randomization.sh your-domain.com live

# Log analysis
tail -f server.log | grep -E "(ServerFailure|normalize)"
```

## Summary

**To verify the problem exists:**
1. Run server with `--no-normalize-case`
2. Monitor for errors and connection failures
3. Detect case randomization with detection scripts

**To validate the fix:**
1. Run server with `--normalize-case` (default)
2. Compare metrics with baseline
3. Verify improved success rate

**To test MTU:**
1. Try different MTU values
2. Monitor performance and compatibility
3. Choose optimal value for your environment

For detailed documentation:
- `docs/case-normalization.md` - Case normalization feature
- `docs/monitoring-case-randomization.md` - Monitoring guide
- `TESTING_GUIDE.md` - Complete testing procedures
