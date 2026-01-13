#!/usr/bin/env bash
# Test multiple DNS resolvers to see which ones work with slipstream-client
# Usage: ./scripts/test-resolvers.sh [resolver1] [resolver2] ...

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="${DOMAIN:-slipstream.example.com}"
TCP_PORT="${TCP_PORT:-7000}"
TEST_TIMEOUT="${TEST_TIMEOUT:-10}"

# Default resolvers to test if none provided
DEFAULT_RESOLVERS=(
    "1.1.1.1:53"
    "8.8.8.8:53"
    "2.189.44.44:53"
    "77.42.91.123:53"
)

# Use provided resolvers or defaults
if [ $# -eq 0 ]; then
    RESOLVERS=("${DEFAULT_RESOLVERS[@]}")
else
    RESOLVERS=("$@")
fi

echo "=== Testing Slipstream DNS Resolvers ==="
echo "Domain: ${DOMAIN}"
echo "TCP Port: ${TCP_PORT}"
echo "Test Timeout: ${TEST_TIMEOUT}s"
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
    
    # Run the client in background with timeout
    timeout "${TEST_TIMEOUT}" "${CLIENT_BIN}" \
        --tcp-listen-port "${TCP_PORT}" \
        --resolver "${resolver}" \
        --domain "${DOMAIN}" \
        >"${LOG_FILE}" 2>&1 &
    CLIENT_PID=$!
    
    # Wait a bit for connection to establish
    sleep 3
    
    # Check if "Connection ready" appears in the log
    if grep -q "Connection ready" "${LOG_FILE}" 2>/dev/null; then
        echo "  ✓ SUCCESS: ${resolver} - Connection ready!"
        WORKING_RESOLVERS+=("${resolver}")
    else
        echo "  ✗ FAILED: ${resolver} - No connection ready message"
        FAILED_RESOLVERS+=("${resolver}")
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
