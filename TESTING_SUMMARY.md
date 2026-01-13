# Complete Testing Summary

## Overview

This guide explains how to test the new features and validate they solve the case randomization problem.

## New Features

### 1. Case Normalization
- **Flag**: `--normalize-case` (default: enabled) or `--no-normalize-case`
- **Purpose**: Handles DNS query case randomization from censorship systems
- **When to use**: In regions with DNS censorship (Iran, China, etc.)

### 2. Configurable MTU
- **Server**: `--mtu <value>` (default: 900)
- **Client**: `--mtu <value>` (default: computed from domain length)
- **Purpose**: Optimize packet size for your network conditions

### 3. Subdomain Length Limit
- **Client**: `--max-subdomain-length <value>` (recommended: 101 for Iran)
- **Purpose**: Limit subdomain length to bypass GFW restrictions
- **When to use**: In regions where GFW blocks subdomains >101 characters

## Testing Procedure

### Part A: Verify Problem Exists (Without Fix)

**Goal**: Confirm that case randomization is causing issues

#### A1. Quick Detection
```bash
./scripts/detect-case-randomization.sh your-domain.com live
```

**Expected Output if problem exists:**
```
⚠ Mixed case detected: AbC123.example.com
🚨 CASE RANDOMIZATION DETECTED!
```

#### A2. Run Server Without Normalization
```bash
# Terminal 1: Server WITHOUT fix
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --no-normalize-case \
    --mtu 900 \
    --debug-streams

# Terminal 2: Client
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com

# Terminal 3: Test connection
ssh -p 7000 user@127.0.0.1
# Or
echo "test" | nc 127.0.0.1 7000
```

**What to observe:**
- Check server logs for `ServerFailure` responses
- Check for `decode failed` errors
- Note connection success/failure rate
- Monitor for 10-15 minutes

#### A3. Capture DNS Queries
```bash
# Monitor DNS traffic
sudo ./scripts/monitor-dns-queries.sh your-domain.com any 600

# Or use Python monitor
python3 scripts/monitor-case-randomization.py \
    --domain your-domain.com \
    --duration 60
```

**Look for:**
- Mixed-case queries (e.g., `AbC123.XyZ.example.com`)
- Inconsistent case patterns
- High percentage of mixed-case queries

### Part B: Test With Fix (With Normalization)

**Goal**: Verify normalization solves the problem

#### B1. Run Server With Normalization
```bash
# Terminal 1: Server WITH fix
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --normalize-case \
    --mtu 900 \
    --debug-streams

# Terminal 2: Same client setup
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com

# Terminal 3: Same tests
ssh -p 7000 user@127.0.0.1
```

**What to observe:**
- Fewer `ServerFailure` responses
- Higher connection success rate
- More stable connections
- Monitor for same duration as Part A

#### B2. Automated Comparison
```bash
# This runs both configurations and compares
./scripts/compare-normalization.sh
```

**Expected Output:**
```
=== Summary ===
With normalization: 95/100 (95%)
Without normalization: 72/100 (72%)
✓ Improvement: 23 queries (32% better)
```

### Part C: Validate Results

#### C1. Compare Metrics

**Manual comparison:**
```bash
# Count errors in baseline
BASELINE_ERRORS=$(grep -c "ServerFailure" server-baseline.log)
BASELINE_SUCCESS=$(grep -c "Connection ready" client-baseline.log)

# Count errors with fix
FIXED_ERRORS=$(grep -c "ServerFailure" server-fixed.log)
FIXED_SUCCESS=$(grep -c "Connection ready" client-fixed.log)

# Calculate improvement
ERROR_REDUCTION=$((BASELINE_ERRORS - FIXED_ERRORS))
SUCCESS_IMPROVEMENT=$((FIXED_SUCCESS - BASELINE_SUCCESS))

echo "Error reduction: $ERROR_REDUCTION"
echo "Success improvement: $SUCCESS_IMPROVEMENT"
```

#### C2. Run Unit Tests
```bash
# Test case normalization logic
cargo test --package slipstream-dns --test case_normalization -- --nocapture
```

**Expected**: All tests pass, shows success rate improvements

#### C3. Analyze DNS Patterns
```bash
# Verify case randomization was handled
python3 scripts/monitor-case-randomization.py \
    --domain your-domain.com \
    --file captured-queries.txt
```

## Valid Test Scenarios

### Scenario 1: Case Randomization Detected

**Setup:**
- Region with DNS censorship (Iran, etc.)
- Case randomization happening

**Test:**
1. Run without normalization → High error rate
2. Run with normalization → Lower error rate
3. **Result**: Fix is working ✅

### Scenario 2: No Case Randomization

**Setup:**
- Region without DNS manipulation
- No case randomization

**Test:**
1. Run without normalization → Works fine
2. Run with normalization → Works fine (no difference)
3. **Result**: No problem to fix, but normalization doesn't hurt ✅

### Scenario 3: Other Issues

**Setup:**
- Network problems, certificate issues, etc.

**Test:**
1. Run without normalization → Errors
2. Run with normalization → Same errors
3. **Result**: Problem is elsewhere, not case-related ⚠️

## MTU Testing

### Test Different MTU Values

```bash
# Small MTU (more compatible, slower)
./slipstream-server --mtu 500 --domain example.com ...

# Default MTU
./slipstream-server --mtu 900 --domain example.com ...

# Large MTU (faster, may hit limits)
./slipstream-server --mtu 1200 --domain example.com ...
```

**Monitor:**
- Connection success rate
- Transfer speed
- DNS query count
- Error rates

**Choose optimal MTU** based on your network conditions.

## Complete Test Checklist

### Pre-Test
- [ ] Certificates generated and valid
- [ ] Domain configured correctly
- [ ] Network connectivity verified
- [ ] Monitoring tools installed (tcpdump, dig, etc.)

### Problem Verification
- [ ] Case randomization detected
- [ ] Server running without normalization
- [ ] Errors observed and logged
- [ ] Metrics collected (baseline)

### Fix Validation
- [ ] Server running with normalization
- [ ] Same test conditions
- [ ] Metrics collected (with fix)
- [ ] Results compared

### Analysis
- [ ] Success rate improved
- [ ] Error count reduced
- [ ] Connection stability improved
- [ ] Fix validated

## Example Test Results

### Without Normalization
```
Total queries: 1000
Successful: 720 (72%)
Failed: 280 (28%)
Errors: ServerFailure (250), decode failed (30)
```

### With Normalization
```
Total queries: 1000
Successful: 950 (95%)
Failed: 50 (5%)
Errors: ServerFailure (45), other (5)
```

### Improvement
```
Success rate: +23% (72% → 95%)
Error reduction: -230 errors (280 → 50)
Improvement: 82% reduction in errors
```

## Quick Commands Reference

```bash
# 1. Detect case randomization problem
./scripts/detect-case-randomization.sh domain.com live

# 2. Test without case normalization
./slipstream-server --no-normalize-case --domain domain.com ...

# 3. Test with case normalization
./slipstream-server --normalize-case --domain domain.com ...

# 4. Test with subdomain length limit (for GFW regions)
./slipstream-client --max-subdomain-length 101 --domain domain.com ...

# 5. Compare automatically
./scripts/compare-normalization.sh

# 6. Monitor DNS
python3 scripts/monitor-case-randomization.py --domain domain.com

# 7. Run unit tests
cargo test --package slipstream-dns --test case_normalization
```

## Success Criteria

**The fix is working if:**
- ✅ Success rate increases significantly (e.g., 70% → 95%)
- ✅ Error count decreases (e.g., 280 → 50)
- ✅ Fewer `ServerFailure` responses
- ✅ More stable connections
- ✅ Case randomization is handled correctly

**The problem doesn't exist if:**
- ✅ No case randomization detected
- ✅ Same results with/without normalization
- ✅ Errors are from other causes

## Troubleshooting

**If normalization doesn't help:**
1. Verify case randomization is actually happening
2. Check for other issues (network, certificates)
3. Verify normalization is enabled
4. Review server logs for other error patterns

**If tests fail:**
1. Check certificates are valid
2. Verify domain configuration
3. Test network connectivity
4. Run unit tests to verify code works

## Next Steps

1. **Run detection** to confirm problem exists
2. **Collect baseline** metrics without fix
3. **Test with fix** and collect metrics
4. **Compare results** to validate improvement
5. **Deploy in production** with normalization enabled
6. **Monitor continuously** to track effectiveness

For detailed documentation:
- `FEATURE_TESTING_GUIDE.md` - Complete testing procedures
- `docs/case-normalization.md` - Feature documentation
- `docs/monitoring-case-randomization.md` - Monitoring guide
