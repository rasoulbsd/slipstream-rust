#!/usr/bin/env bash
# Test your specific list of DNS resolvers
# Usage: ./scripts/test-my-resolvers.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="${DOMAIN:-slipstream.meonme.ir}"
TCP_PORT="${TCP_PORT:-7000}"
TEST_TIMEOUT="${TEST_TIMEOUT:-15}"
CONNECTION_WAIT="${CONNECTION_WAIT:-7}"

# Your resolver list
RESOLVERS=(
    "1.1.1.1:53"
    "2.188.21.20:53"
    "2.188.21.90:53"
    "2.188.21.100:53"
    "2.188.21.120:53"
    "2.188.21.130:53"
    "2.188.21.190:53"
    "2.188.21.200:53"
    "2.188.21.230:53"
    "2.188.21.240:53"
    "2.189.44.44:53"
    "37.152.190.80:53"
    "95.38.94.218:53"
    "217.218.26.77:53"
    "217.218.26.78:53"
    "217.218.127.126:53"
)

echo "=== Testing Slipstream DNS Resolvers ==="
echo "Domain: ${DOMAIN}"
echo "TCP Port: ${TCP_PORT}"
echo "Test Timeout: ${TEST_TIMEOUT}s"
echo "Connection Wait: ${CONNECTION_WAIT}s"
echo "Resolvers to test: ${#RESOLVERS[@]}"
echo ""

# Build the client if needed
if [ ! -f "${ROOT_DIR}/target/debug/slipstream-client" ] && [ ! -f "${ROOT_DIR}/target/release/slipstream-client" ]; then
    echo "Building slipstream-client..."
    cargo build -p slipstream-client
fi

CLIENT_BIN="${ROOT_DIR}/target/release/slipstream-client"
if [ ! -f "${CLIENT_BIN}" ]; then
    CLIENT_BIN="${ROOT_DIR}/target/debug/slipstream-client"
fi

WORKING_RESOLVERS=()
FAILED_RESOLVERS=()

for resolver in "${RESOLVERS[@]}"; do
    echo "Testing resolver: ${resolver}..."
    
    # Create a temporary log file
    LOG_FILE=$(mktemp)
    
    # Run the client in background with timeout and unbuffered output
    # Use stdbuf if available to make output line-buffered, otherwise rely on frequent checks
    if command -v stdbuf >/dev/null 2>&1; then
        timeout "${TEST_TIMEOUT}" stdbuf -oL -eL "${CLIENT_BIN}" \
            --tcp-listen-port "${TCP_PORT}" \
            --resolver "${resolver}" \
            --domain "${DOMAIN}" \
            >"${LOG_FILE}" 2>&1 &
    else
        timeout "${TEST_TIMEOUT}" "${CLIENT_BIN}" \
            --tcp-listen-port "${TCP_PORT}" \
            --resolver "${resolver}" \
            --domain "${DOMAIN}" \
            >"${LOG_FILE}" 2>&1 &
    fi
    CLIENT_PID=$!
    
    # Wait and check continuously for connection to establish (up to CONNECTION_WAIT seconds)
    # Check every 0.5 seconds to catch output quickly (14 checks for 7 seconds)
    CONNECTED=false
    CHECKS=$((CONNECTION_WAIT * 2))  # Check twice per second
    CHECK_COUNT=0
    while [ $CHECK_COUNT -lt $CHECKS ]; do
        sleep 0.5
        CHECK_COUNT=$((CHECK_COUNT + 1))
        # Force sync to ensure file is written (if available)
        sync "${LOG_FILE}" 2>/dev/null || true
        if grep -q "Connection ready" "${LOG_FILE}" 2>/dev/null; then
            CONNECTED=true
            break
        fi
    done
    
    # Check if "Connection ready" appears in the log
    if [ "$CONNECTED" = true ]; then
        echo "  ✓ SUCCESS: ${resolver} - Connection ready!"
        WORKING_RESOLVERS+=("${resolver}")
    else
        # Final check - sometimes output appears right after the loop
        sync "${LOG_FILE}" 2>/dev/null || true
        sleep 0.5
        if grep -q "Connection ready" "${LOG_FILE}" 2>/dev/null; then
            echo "  ✓ SUCCESS: ${resolver} - Connection ready! (detected on final check)"
            WORKING_RESOLVERS+=("${resolver}")
        else
            echo "  ✗ FAILED: ${resolver} - No connection ready message after ${CONNECTION_WAIT}s"
            # Debug: show last few lines of log
            if [ -s "${LOG_FILE}" ]; then
                echo "    Last log lines:"
                tail -n 3 "${LOG_FILE}" | sed 's/^/      /'
            fi
            FAILED_RESOLVERS+=("${resolver}")
        fi
    fi
    
    # Kill the client process
    kill "${CLIENT_PID}" 2>/dev/null || true
    wait "${CLIENT_PID}" 2>/dev/null || true
    
    # Clean up log file
    rm -f "${LOG_FILE}"
    
    # Small delay between tests
    sleep 1
done

echo ""
echo "=== Test Results ==="
echo ""
echo "Working resolvers (${#WORKING_RESOLVERS[@]}):"
if [ ${#WORKING_RESOLVERS[@]} -eq 0 ]; then
    echo "  None"
else
    for resolver in "${WORKING_RESOLVERS[@]}"; do
        echo "  ✓ ${resolver}"
    done
fi

echo ""
echo "Failed resolvers (${#FAILED_RESOLVERS[@]}):"
if [ ${#FAILED_RESOLVERS[@]} -eq 0 ]; then
    echo "  None"
else
    for resolver in "${FAILED_RESOLVERS[@]}"; do
        echo "  ✗ ${resolver}"
    done
fi

echo ""
if [ ${#WORKING_RESOLVERS[@]} -gt 0 ]; then
    echo "Recommended resolver: ${WORKING_RESOLVERS[0]}"
    echo ""
    echo "Use it with:"
    echo "  cargo run -p slipstream-client -- \\"
    echo "    --tcp-listen-port ${TCP_PORT} \\"
    echo "    --resolver ${WORKING_RESOLVERS[0]} \\"
    echo "    --domain ${DOMAIN}"
fi

exit 0
