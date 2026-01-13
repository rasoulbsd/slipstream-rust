#!/usr/bin/env bash
set -euo pipefail

# Live test script to compare case normalization with/without the flag
# This sends test queries and measures success rates

DOMAIN="${DOMAIN:-example.com}"
SERVER_PORT="${SERVER_PORT:-53}"
TEST_ITERATIONS="${TEST_ITERATIONS:-100}"

echo "=== Live Case Normalization Test ==="
echo "Domain: $DOMAIN"
echo "Server port: $SERVER_PORT"
echo "Iterations: $TEST_ITERATIONS"
echo ""

# Function to randomize case in a string
randomize_case() {
    local input="$1"
    local result=""
    for ((i=0; i<${#input}; i++)); do
        char="${input:$i:1}"
        if [[ "$char" =~ [A-Za-z] ]]; then
            # Randomize case based on position
            if (( (i + $(printf '%d' "'$char")) % 2 == 0 )); then
                result+=$(echo "$char" | tr '[:lower:]' '[:upper:]')
            else
                result+=$(echo "$char" | tr '[:upper:]' '[:lower:]')
            fi
        else
            result+="$char"
        fi
    done
    echo "$result"
}

# Function to test with a specific server configuration
test_server() {
    local normalize_flag="$1"
    local label="$2"
    
    echo "Testing with $label..."
    
    # Start server in background
    SERVER_PID=""
    if [ "$normalize_flag" = "enabled" ]; then
        cargo run -p slipstream-server -- \
            --dns-listen-port "$SERVER_PORT" \
            --domain "$DOMAIN" \
            --cert .github/certs/cert.pem \
            --key .github/certs/key.pem \
            --normalize-case \
            > /tmp/slipstream-server.log 2>&1 &
        SERVER_PID=$!
    else
        cargo run -p slipstream-server -- \
            --dns-listen-port "$SERVER_PORT" \
            --domain "$DOMAIN" \
            --cert .github/certs/cert.pem \
            --key .github/certs/key.pem \
            --no-normalize-case \
            > /tmp/slipstream-server.log 2>&1 &
        SERVER_PID=$!
    fi
    
    # Wait for server to start
    sleep 2
    
    local success=0
    local failed=0
    
    # Generate test payloads and send queries
    for ((i=1; i<=TEST_ITERATIONS; i++)); do
        # Create a test payload
        payload="test-payload-$i"
        
        # Encode to base32 (simplified - in real test, use actual encoding)
        # For this test, we'll use dig to send actual queries
        test_subdomain=$(echo -n "$payload" | base32 | tr -d '=')
        
        # Randomize case
        randomized=$(randomize_case "$test_subdomain")
        qname="${randomized}.${DOMAIN}"
        
        # Send DNS query
        if dig @"127.0.0.1" -p "$SERVER_PORT" +short "$qname" TXT > /dev/null 2>&1; then
            ((success++))
        else
            ((failed++))
        fi
        
        # Progress indicator
        if ((i % 10 == 0)); then
            echo -n "."
        fi
    done
    
    echo ""
    echo "Results for $label:"
    echo "  Success: $success/$TEST_ITERATIONS ($((success * 100 / TEST_ITERATIONS))%)"
    echo "  Failed: $failed/$TEST_ITERATIONS ($((failed * 100 / TEST_ITERATIONS))%)"
    echo ""
    
    # Kill server
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    echo "$success"
}

# Check prerequisites
if ! command -v dig &> /dev/null; then
    echo "Error: dig not found. Install with: sudo apt-get install dnsutils"
    exit 1
fi

# Run tests
echo "Starting tests..."
echo ""

SUCCESS_WITH=$(test_server "enabled" "normalization ENABLED")
sleep 1
SUCCESS_WITHOUT=$(test_server "disabled" "normalization DISABLED")

echo "=== Summary ==="
echo "With normalization: $SUCCESS_WITH/$TEST_ITERATIONS"
echo "Without normalization: $SUCCESS_WITHOUT/$TEST_ITERATIONS"
echo ""

if [ "$SUCCESS_WITH" -gt "$SUCCESS_WITHOUT" ]; then
    echo "✓ Normalization improves success rate by $((SUCCESS_WITH - SUCCESS_WITHOUT)) queries"
elif [ "$SUCCESS_WITH" -eq "$SUCCESS_WITHOUT" ]; then
    echo "→ Normalization has no significant impact (both: $SUCCESS_WITH/$TEST_ITERATIONS)"
else
    echo "⚠ Normalization appears to reduce success rate (unexpected)"
fi
