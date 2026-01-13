#!/usr/bin/env bash
set -euo pipefail

# Monitor DNS queries and log case patterns
# This script helps detect if case randomization is happening

DOMAIN="${1:-example.com}"
INTERFACE="${2:-any}"
DURATION="${3:-300}"  # 5 minutes default

OUTPUT_FILE="dns-case-analysis-$(date +%Y%m%d-%H%M%S).log"

echo "=== DNS Case Randomization Monitor ==="
echo "Domain: $DOMAIN"
echo "Interface: $INTERFACE"
echo "Duration: ${DURATION}s"
echo "Output: $OUTPUT_FILE"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Warning: Not running as root. Some features may not work."
    echo "For full monitoring, run with: sudo $0 $*"
    echo ""
fi

# Function to analyze case in a query name
analyze_case() {
    local qname="$1"
    local subdomain="${qname%%.*}"
    local upper=$(echo "$subdomain" | tr -cd 'A-Z' | wc -c)
    local lower=$(echo "$subdomain" | tr -cd 'a-z' | wc -c)
    local total=$((upper + lower))
    
    if [ "$total" -eq 0 ]; then
        echo "no-alpha"
        return
    fi
    
    if [ "$upper" -gt 0 ] && [ "$lower" -gt 0 ]; then
        echo "mixed"
    elif [ "$upper" -gt 0 ]; then
        echo "upper"
    else
        echo "lower"
    fi
}

# Capture DNS queries
echo "Starting capture..."
echo "Timestamp,Query,Case Pattern,Upper Count,Lower Count" > "$OUTPUT_FILE"

if command -v tcpdump &> /dev/null; then
    timeout "$DURATION" tcpdump -i "$INTERFACE" -n -l "udp port 53" 2>/dev/null | \
    while IFS= read -r line; do
        # Extract query name (simplified - adjust regex as needed)
        if echo "$line" | grep -q "$DOMAIN"; then
            qname=$(echo "$line" | grep -oE '[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+' | head -1)
            if [ -n "$qname" ] && echo "$qname" | grep -q "$DOMAIN"; then
                case_pattern=$(analyze_case "$qname")
                upper=$(echo "${qname%%.*}" | tr -cd 'A-Z' | wc -c)
                lower=$(echo "${qname%%.*}" | tr -cd 'a-z' | wc -c)
                timestamp=$(date +%Y-%m-%dT%H:%M:%S)
                echo "$timestamp,$qname,$case_pattern,$upper,$lower" >> "$OUTPUT_FILE"
                echo "[$timestamp] $qname -> $case_pattern"
            fi
        fi
    done
else
    echo "Error: tcpdump not found. Install with: sudo apt-get install tcpdump"
    exit 1
fi

echo ""
echo "Capture complete. Analyzing results..."
echo ""

# Analyze results
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    total=$(tail -n +2 "$OUTPUT_FILE" | wc -l)
    mixed=$(tail -n +2 "$OUTPUT_FILE" | grep -c ",mixed," || echo "0")
    upper=$(tail -n +2 "$OUTPUT_FILE" | grep -c ",upper," || echo "0")
    lower=$(tail -n +2 "$OUTPUT_FILE" | grep -c ",lower," || echo "0")
    
    echo "=== Results ==="
    echo "Total queries: $total"
    echo "Mixed case: $mixed ($((mixed * 100 / total))%)"
    echo "All uppercase: $upper ($((upper * 100 / total))%)"
    echo "All lowercase: $lower ($((lower * 100 / total))%)"
    echo ""
    
    if [ "$mixed" -gt 0 ]; then
        echo "⚠️  WARNING: Case randomization detected!"
        echo "   $mixed out of $total queries have mixed case"
        echo "   This suggests DNS queries are being modified"
        echo "   Recommendation: Enable --normalize-case on server"
    else
        echo "✓ No case randomization detected"
    fi
    
    echo ""
    echo "Detailed log saved to: $OUTPUT_FILE"
else
    echo "No queries captured. Check interface and domain settings."
fi
