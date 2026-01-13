#!/usr/bin/env bash
set -euo pipefail

# Compare server behavior with and without case normalization
# This script runs both configurations and compares results

DOMAIN="${DOMAIN:-example.com}"
SERVER_PORT="${SERVER_PORT:-8853}"
TEST_DURATION="${TEST_DURATION:-60}"

echo "=== Case Normalization Comparison Test ==="
echo "Domain: $DOMAIN"
echo "Server port: $SERVER_PORT"
echo "Test duration: ${TEST_DURATION}s"
echo ""

# Create test results directory
RESULTS_DIR="test-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Function to run server and collect metrics
run_test() {
    local normalize_enabled="$1"
    local label="$2"
    local log_file="$RESULTS_DIR/server-${label}.log"
    local metrics_file="$RESULTS_DIR/metrics-${label}.txt"
    
    echo "Testing: $label"
    
    # Build server command
    local server_cmd=(
        cargo run -p slipstream-server --release --
        --dns-listen-port "$SERVER_PORT"
        --domain "$DOMAIN"
        --cert .github/certs/cert.pem
        --key .github/certs/key.pem
    )
    
    if [ "$normalize_enabled" = "true" ]; then
        server_cmd+=(--normalize-case)
    else
        server_cmd+=(--no-normalize-case)
    fi
    
    # Start server
    "${server_cmd[@]}" > "$log_file" 2>&1 &
    local server_pid=$!
    
    # Wait for server to start
    sleep 3
    
    # Check if server is running
    if ! kill -0 $server_pid 2>/dev/null; then
        echo "  ❌ Server failed to start. Check $log_file"
        return 1
    fi
    
    echo "  ✓ Server started (PID: $server_pid)"
    
    # Monitor for test duration
    local start_time=$(date +%s)
    local success_count=0
    local error_count=0
    local total_queries=0
    
    while [ $(($(date +%s) - start_time)) -lt "$TEST_DURATION" ]; do
        # Send test query (simplified - adjust as needed)
        if dig @"127.0.0.1" -p "$SERVER_PORT" +short "test.${DOMAIN}" TXT > /dev/null 2>&1; then
            ((success_count++))
        else
            ((error_count++))
        fi
        ((total_queries++))
        sleep 1
    done
    
    # Stop server
    kill $server_pid 2>/dev/null || true
    wait $server_pid 2>/dev/null || true
    
    # Save metrics
    {
        echo "Test: $label"
        echo "Duration: ${TEST_DURATION}s"
        echo "Total queries: $total_queries"
        echo "Success: $success_count"
        echo "Errors: $error_count"
        echo "Success rate: $((success_count * 100 / total_queries))%"
    } > "$metrics_file"
    
    echo "  Results: $success_count/$total_queries successful ($((success_count * 100 / total_queries))%)"
    echo ""
    
    echo "$success_count"
}

# Run both tests
echo "Starting tests..."
echo ""

SUCCESS_WITH=$(run_test "true" "with-normalization")
SUCCESS_WITHOUT=$(run_test "false" "without-normalization")

# Generate comparison report
{
    echo "=== Case Normalization Comparison Report ==="
    echo "Generated: $(date)"
    echo ""
    echo "Test Configuration:"
    echo "  Domain: $DOMAIN"
    echo "  Port: $SERVER_PORT"
    echo "  Duration: ${TEST_DURATION}s"
    echo ""
    echo "Results:"
    echo "  With normalization: $SUCCESS_WITH queries successful"
    echo "  Without normalization: $SUCCESS_WITHOUT queries successful"
    echo ""
    
    if [ "$SUCCESS_WITH" -gt "$SUCCESS_WITHOUT" ]; then
        DIFF=$((SUCCESS_WITH - SUCCESS_WITHOUT))
        echo "✓ Normalization improves success rate by $DIFF queries"
        echo "  Improvement: $((DIFF * 100 / SUCCESS_WITHOUT))%"
    elif [ "$SUCCESS_WITH" -eq "$SUCCESS_WITHOUT" ]; then
        echo "→ Normalization has no significant impact"
    else
        echo "⚠ Unexpected: Normalization appears to reduce success rate"
    fi
    echo ""
    echo "Detailed logs available in: $RESULTS_DIR"
} > "$RESULTS_DIR/comparison-report.txt"

cat "$RESULTS_DIR/comparison-report.txt"
echo ""
echo "Full results saved to: $RESULTS_DIR"
