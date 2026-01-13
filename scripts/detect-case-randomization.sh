#!/usr/bin/env bash
set -euo pipefail

# Quick script to detect if case randomization is happening
# Analyzes recent DNS queries or live traffic

DOMAIN="${1:-example.com}"
MODE="${2:-live}"  # 'live' or 'file'

echo "=== Case Randomization Detector ==="
echo "Domain: $DOMAIN"
echo "Mode: $MODE"
echo ""

if [ "$MODE" = "live" ]; then
    echo "Capturing live DNS traffic for 30 seconds..."
    echo "(Requires root/sudo for tcpdump)"
    echo ""
    
    if ! command -v tcpdump &> /dev/null; then
        echo "Error: tcpdump not found"
        exit 1
    fi
    
    # Capture queries
    CAPTURE_FILE="/tmp/dns-capture-$$.txt"
    timeout 30 tcpdump -i any -n -l "udp port 53" 2>/dev/null | \
        grep -i "$DOMAIN" | \
        grep -oE '[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+' | \
        grep -i "$DOMAIN" | \
        sort -u > "$CAPTURE_FILE" || true
    
    if [ ! -s "$CAPTURE_FILE" ]; then
        echo "No queries captured. Make sure DNS traffic is being generated."
        rm -f "$CAPTURE_FILE"
        exit 1
    fi
    
    QUERIES=$(cat "$CAPTURE_FILE")
    rm -f "$CAPTURE_FILE"
else
    # Read from file
    FILE="${3:-}"
    if [ -z "$FILE" ]; then
        echo "Error: File mode requires a file path"
        exit 1
    fi
    QUERIES=$(cat "$FILE")
fi

# Analyze queries
MIXED_COUNT=0
TOTAL_COUNT=0

while IFS= read -r qname; do
    [ -z "$qname" ] && continue
    
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # Extract subdomain
    subdomain="${qname%%.*}"
    
    # Check for mixed case
    has_upper=$(echo "$subdomain" | grep -q '[A-Z]' && echo "yes" || echo "no")
    has_lower=$(echo "$subdomain" | grep -q '[a-z]' && echo "yes" || echo "no")
    
    if [ "$has_upper" = "yes" ] && [ "$has_lower" = "yes" ]; then
        MIXED_COUNT=$((MIXED_COUNT + 1))
        echo "⚠ Mixed case detected: $qname"
    fi
done <<< "$QUERIES"

echo ""
echo "=== Analysis ==="
echo "Total queries analyzed: $TOTAL_COUNT"
echo "Mixed case queries: $MIXED_COUNT"

if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo ""
    echo "No queries found. Check domain and capture settings."
    exit 1
fi

MIXED_PERCENT=$((MIXED_COUNT * 100 / TOTAL_COUNT))

echo "Mixed case percentage: $MIXED_PERCENT%"
echo ""

if [ "$MIXED_COUNT" -gt 0 ]; then
    echo "🚨 CASE RANDOMIZATION DETECTED!"
    echo ""
    echo "Recommendation:"
    echo "  Enable case normalization on your server:"
    echo "    ./slipstream-server --domain $DOMAIN --normalize-case ..."
    echo ""
    echo "  Or test if it helps:"
    echo "    ./scripts/compare-normalization.sh"
    exit 2
else
    echo "✓ No case randomization detected"
    echo "  All queries appear to have consistent case"
    exit 0
fi
