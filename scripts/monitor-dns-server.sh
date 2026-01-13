#!/usr/bin/env bash
# Monitor DNS queries on the server side
# Usage: ./scripts/monitor-dns-server.sh [port] [domain]

set -euo pipefail

PORT="${1:-8853}"
DOMAIN="${2:-}"

echo "=== Monitoring DNS traffic on port $PORT ==="
echo "Press Ctrl+C to stop"
echo ""

if command -v tcpdump &> /dev/null; then
    if [ -n "$DOMAIN" ]; then
        echo "Filtering for domain: $DOMAIN"
        sudo tcpdump -i any -n -v -s 0 port $PORT and udp 2>&1 | grep -E "(domain|$DOMAIN|length|size)" --color=always
    else
        echo "Showing all DNS traffic on port $PORT"
        sudo tcpdump -i any -n -v -s 0 port $PORT and udp
    fi
elif command -v wireshark &> /dev/null; then
    echo "Starting Wireshark (requires GUI)..."
    sudo wireshark -i any -f "udp port $PORT" &
else
    echo "Error: tcpdump or wireshark not found"
    echo "Install with: sudo apt-get install tcpdump wireshark"
    exit 1
fi
