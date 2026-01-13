#!/usr/bin/env bash
set -euo pipefail

# Test script to compare case normalization behavior
# This simulates GFW case randomization and tests if normalization helps

echo "=== Case Normalization Test Suite ==="
echo ""

# Build the test binary
echo "Building tests..."
cargo build --release -p slipstream-dns 2>&1 | grep -E "(Compiling|Finished)" || true

# Run the case normalization tests
echo ""
echo "Running case normalization tests..."
cargo test --package slipstream-dns --test case_normalization -- --nocapture

echo ""
echo "=== Test Summary ==="
echo "Tests completed. Check output above for success rates."
echo ""
echo "=== Additional Testing Options ==="
echo ""
echo "1. Quick detection:"
echo "   ./scripts/detect-case-randomization.sh your-domain.com live"
echo ""
echo "2. Detailed monitoring:"
echo "   python3 scripts/monitor-case-randomization.py --domain your-domain.com --duration 60"
echo ""
echo "3. Compare with/without normalization:"
echo "   ./scripts/compare-normalization.sh"
echo ""
echo "4. Live test with randomized queries:"
echo "   ./scripts/test-case-normalization-live.sh"
echo ""
echo "See docs/monitoring-case-randomization.md for detailed instructions."
