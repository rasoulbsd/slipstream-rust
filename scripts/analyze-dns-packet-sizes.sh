#!/usr/bin/env bash
# Analyze DNS packet sizes from tcpdump output
# Usage: ./scripts/analyze-dns-packet-sizes.sh [port] [duration_seconds]

set -euo pipefail

PORT="${1:-8853}"
DURATION="${2:-60}"
OUTPUT_FILE="/tmp/dns-packets-$$.txt"

echo "=== Capturing DNS packets for $DURATION seconds ==="
echo "Output: $OUTPUT_FILE"
echo ""

# Capture packets
timeout $DURATION sudo tcpdump -i any -n -l port $PORT and udp 2>&1 | \
    tee "$OUTPUT_FILE" | \
    grep -E "length|>|domain" || true

echo ""
echo "=== Analysis ==="
echo ""

# Extract packet sizes
if [ -f "$OUTPUT_FILE" ]; then
    echo "Packet size distribution:"
    grep -oP 'length \K\d+' "$OUTPUT_FILE" 2>/dev/null | \
        sort -n | \
        uniq -c | \
        sort -rn | \
        head -20 || echo "No packets captured"
    
    echo ""
    echo "Min/Max/Avg packet sizes:"
    grep -oP 'length \K\d+' "$OUTPUT_FILE" 2>/dev/null | \
        awk '{
            sum+=$1; 
            if(NR==1 || $1<min) min=$1; 
            if(NR==1 || $1>max) max=$1; 
            count++
        } 
        END {
            if(count>0) {
                printf "Min: %d bytes\nMax: %d bytes\nAvg: %.1f bytes\nCount: %d packets\n", min, max, sum/count, count
            } else {
                print "No packets found"
            }
        }'
    
    rm -f "$OUTPUT_FILE"
else
    echo "No capture file found"
fi
