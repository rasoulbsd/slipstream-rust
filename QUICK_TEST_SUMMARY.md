# Quick Test Summary

## New Features

1. **Case Normalization**: `--normalize-case` (default: enabled)
2. **MTU Configuration**: `--mtu <value>` (server default: 900, client: computed)
3. **Subdomain Length Limit**: `--max-subdomain-length <value>` (recommended: 101 for Iran/GFW)

## How to Test if Problem Exists (Without Fix)

### Method 1: Quick Detection
```bash
./scripts/detect-case-randomization.sh your-domain.com live
```
**Expected if problem exists**: "🚨 CASE RANDOMIZATION DETECTED!"

### Method 2: Run Server Without Normalization
```bash
# Start server WITHOUT fix
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --no-normalize-case \
    --debug-streams

# Start client
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com

# Try to connect - if you see errors, problem exists
```

**Look for:**
- `ServerFailure` in server logs
- `decode failed` errors
- Connection failures
- Mixed-case DNS queries

## How to Validate Fix Works

### Method 1: Automated Comparison
```bash
./scripts/compare-normalization.sh
```
**Expected**: Higher success rate with normalization

### Method 2: Manual Test
```bash
# Test WITHOUT (baseline)
./slipstream-server --no-normalize-case ... > baseline.log 2>&1
# Monitor for 10 min, count errors

# Test WITH (fix)
./slipstream-server --normalize-case ... > fixed.log 2>&1  
# Monitor for 10 min, count errors

# Compare
echo "Baseline errors: $(grep -c ServerFailure baseline.log)"
echo "Fixed errors: $(grep -c ServerFailure fixed.log)"
```

**Expected**: Fewer errors with normalization

### Method 3: Unit Tests
```bash
cargo test --package slipstream-dns --test case_normalization -- --nocapture
```
**Expected**: All tests pass, shows success rate improvements

## Complete Test Procedure

### Step 1: Verify Problem
```bash
# Detect case randomization
./scripts/detect-case-randomization.sh your-domain.com live

# If detected, problem exists - proceed to Step 2
```

### Step 2: Baseline (Without Fix)
```bash
# Server without normalization
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --no-normalize-case \
    --mtu 900 \
    --debug-streams > baseline.log 2>&1 &

# Client
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com > client-baseline.log 2>&1 &

# Test for 10-15 minutes
# Count: errors, successful connections
```

### Step 3: Test With Fix
```bash
# Server with normalization
./slipstream-server \
    --domain your-domain.com \
    --cert cert.pem \
    --key key.pem \
    --normalize-case \
    --mtu 900 \
    --debug-streams > fixed.log 2>&1 &

# Same client setup
./slipstream-client \
    --tcp-listen-port 7000 \
    --resolver <server-ip>:53 \
    --domain your-domain.com > client-fixed.log 2>&1 &

# Test for same duration
# Count: errors, successful connections
```

### Step 4: Compare Results
```bash
# Automated
./scripts/compare-normalization.sh

# Or manual
echo "Baseline: $(grep -c ServerFailure baseline.log) errors"
echo "Fixed: $(grep -c ServerFailure fixed.log) errors"
echo "Improvement: $(( $(grep -c ServerFailure baseline.log) - $(grep -c ServerFailure fixed.log) )) errors"
```

## Valid Test Results

### ✅ Fix is Working If:
- Success rate increases (e.g., 72% → 95%)
- Error count decreases
- Fewer `ServerFailure` responses
- More stable connections
- Case randomization is handled correctly

### ❌ Problem Doesn't Exist If:
- No case randomization detected
- Same results with/without normalization
- Errors are from other causes (network, certs, etc.)

### ⚠️ Fix Not Helping If:
- Same error rate with/without normalization
- Different type of errors (not decode failures)
- Network or certificate issues

## MTU Testing

```bash
# Test different MTU values
./slipstream-server --mtu 500 ...  # Smaller
./slipstream-server --mtu 1200 ... # Larger
./slipstream-server --mtu 900 ...  # Default

# Monitor performance and choose optimal value
```

## Quick Reference

| Task | Command |
|------|---------|
| Detect problem | `./scripts/detect-case-randomization.sh domain.com live` |
| Test without fix | `./slipstream-server --no-normalize-case ...` |
| Test with fix | `./slipstream-server --normalize-case ...` |
| Compare | `./scripts/compare-normalization.sh` |
| Unit tests | `cargo test --package slipstream-dns --test case_normalization` |
| Monitor | `python3 scripts/monitor-case-randomization.py --domain domain.com` |

## Expected Outcomes

**If case randomization is happening:**
- Without normalization: High error rate, connection failures
- With normalization: Lower error rate, better connections

**If case randomization is NOT happening:**
- Both configurations work similarly
- Errors are from other causes

See `FEATURE_TESTING_GUIDE.md` for detailed procedures.
