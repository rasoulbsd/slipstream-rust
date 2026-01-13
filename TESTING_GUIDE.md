# Testing and Monitoring Case Normalization

## Quick Start

### 1. Detect if Case Randomization is Happening

```bash
# Quick detection (30 seconds)
./scripts/detect-case-randomization.sh your-domain.com live

# Output will tell you if randomization is detected
```

### 2. Run Unit Tests

```bash
# Run the test suite
cargo test --package slipstream-dns --test case_normalization -- --nocapture

# Or use the test script
./scripts/test-case-normalization.sh
```

### 3. Compare With/Without Normalization

```bash
# Automated comparison test
./scripts/compare-normalization.sh
```

## Monitoring Tools

### Tool 1: Quick Detector (`detect-case-randomization.sh`)

**Purpose**: Quickly detect if case randomization is happening

```bash
# Live detection
./scripts/detect-case-randomization.sh example.com live

# From log file
./scripts/detect-case-randomization.sh example.com file dns-queries.log
```

**Output**:
- ✅ No randomization detected
- 🚨 CASE RANDOMIZATION DETECTED (with recommendations)

### Tool 2: Python Monitor (`monitor-case-randomization.py`)

**Purpose**: Detailed analysis with statistics

```bash
# Monitor live traffic
python3 scripts/monitor-case-randomization.py \
    --domain example.com \
    --interface any \
    --duration 60

# Analyze from file
python3 scripts/monitor-case-randomization.py \
    --domain example.com \
    --file queries.txt
```

**Output**: Detailed statistics including:
- Total queries
- Mixed case percentage
- Case distribution
- Example queries

### Tool 3: Bash Monitor (`monitor-dns-queries.sh`)

**Purpose**: Simple monitoring with logging

```bash
# Monitor for 5 minutes
sudo ./scripts/monitor-dns-queries.sh example.com any 300
```

**Output**: CSV log file with timestamps and case patterns

### Tool 4: Comparison Test (`compare-normalization.sh`)

**Purpose**: Compare server behavior with/without normalization

```bash
# Run comparison
DOMAIN=your-domain.com ./scripts/compare-normalization.sh
```

**Output**: Success rates for both configurations

## Step-by-Step Testing Procedure

### Phase 1: Detection

1. **Check if randomization is happening**:
   ```bash
   ./scripts/detect-case-randomization.sh your-domain.com live
   ```

2. **If detected, proceed to Phase 2**

### Phase 2: Baseline Measurement

1. **Run server WITHOUT normalization**:
   ```bash
   ./slipstream-server \
       --domain your-domain.com \
       --cert cert.pem \
       --key key.pem \
       --no-normalize-case \
       --debug-streams
   ```

2. **Monitor for 10-15 minutes**, collect:
   - Connection success rate
   - Error messages in logs
   - DNS query patterns

3. **Record metrics**:
   ```bash
   # Count errors
   grep -c "ServerFailure\|decode failed" server.log
   
   # Count successful connections
   grep -c "Connection ready" client.log
   ```

### Phase 3: Test With Normalization

1. **Run server WITH normalization**:
   ```bash
   ./slipstream-server \
       --domain your-domain.com \
       --cert cert.pem \
       --key key.pem \
       --normalize-case \
       --debug-streams
   ```

2. **Monitor for same duration**, collect same metrics

3. **Compare results**

### Phase 4: Analysis

Compare metrics:
- Success rate improvement
- Error reduction
- Connection stability

## Production Monitoring

### Continuous Monitoring Script

Create `/usr/local/bin/monitor-slipstream.sh`:

```bash
#!/bin/bash
DOMAIN="your-domain.com"
LOG_FILE="/var/log/slipstream-case-monitor.log"

# Run detection
./scripts/detect-case-randomization.sh "$DOMAIN" live >> "$LOG_FILE" 2>&1

# Check if randomization detected
if grep -q "CASE RANDOMIZATION DETECTED" "$LOG_FILE"; then
    # Send alert
    echo "Alert: Case randomization detected at $(date)" | \
        mail -s "Slipstream Alert" admin@example.com
fi
```

Add to cron:
```bash
# Run every hour
0 * * * * /usr/local/bin/monitor-slipstream.sh
```

### Server Log Analysis

Monitor server logs for patterns:

```bash
# Watch for decode failures
tail -f server.log | grep -E "(ServerFailure|decode failed|base32)"

# Count errors by type
grep -E "ServerFailure|NameError|FormatError" server.log | \
    sort | uniq -c | sort -rn
```

### Client-Side Monitoring

Monitor client connection success:

```bash
# Track connection attempts
grep "Connection ready" client.log | wc -l

# Track failures
grep -E "Connection closed|failed" client.log | wc -l
```

## Interpreting Results

### Good Signs (Normalization Helping)
- ✅ Higher success rate with normalization
- ✅ Fewer `ServerFailure` responses
- ✅ More stable connections
- ✅ Reduced error rate

### Bad Signs (Normalization Not Helping)
- ❌ Same or lower success rate
- ❌ Still seeing decode failures
- ❌ No improvement in error rate

### If Normalization Doesn't Help
1. Check if case randomization is actually the problem
2. Look for other issues (network, certificates, etc.)
3. Verify normalization is actually enabled
4. Check server logs for other error patterns

## Example Test Session

```bash
# 1. Detect randomization
$ ./scripts/detect-case-randomization.sh example.com live
⚠ Mixed case detected: AbC123.example.com
⚠ Mixed case detected: XyZ456.example.com
🚨 CASE RANDOMIZATION DETECTED!

# 2. Run comparison test
$ ./scripts/compare-normalization.sh
Testing: with-normalization
  ✓ Server started
  Results: 95/100 successful (95%)

Testing: without-normalization  
  ✓ Server started
  Results: 72/100 successful (72%)

=== Summary ===
✓ Normalization improves success rate by 23 queries
  Improvement: 32%

# 3. Monitor in production
$ python3 scripts/monitor-case-randomization.py \
    --domain example.com \
    --duration 300

Total queries analyzed: 150
Mixed case queries: 45 (30.0%)
⚠️  WARNING: Case randomization detected!
```

## Troubleshooting

### Scripts not working?

1. **Check permissions**:
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Install dependencies**:
   ```bash
   # For Python script
   pip3 install -r requirements.txt  # if needed
   
   # For tcpdump
   sudo apt-get install tcpdump dnsutils
   ```

3. **Check Python version**:
   ```bash
   python3 --version  # Should be 3.6+
   ```

### No queries captured?

1. **Check interface**:
   ```bash
   ip addr show  # List interfaces
   # Use correct interface name
   ```

2. **Check domain**:
   ```bash
   # Make sure domain matches your setup
   ```

3. **Generate test traffic**:
   ```bash
   # Send test queries
   dig @127.0.0.1 -p 53 test.example.com TXT
   ```

## Next Steps

1. **Run detection** to confirm if randomization is happening
2. **Run comparison test** to measure improvement
3. **Monitor in production** to track long-term effects
4. **Adjust configuration** based on results

For detailed documentation, see `docs/monitoring-case-randomization.md`
