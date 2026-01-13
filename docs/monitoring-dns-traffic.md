# Monitoring DNS Traffic on Server Side

## Quick Start

### 1. Real-time Monitoring

```bash
# Monitor all DNS traffic on port 8853
sudo ./scripts/monitor-dns-server.sh 8853

# Monitor specific domain
sudo ./scripts/monitor-dns-server.sh 8853 example.com
```

### 2. Analyze Packet Sizes

```bash
# Capture for 60 seconds and analyze
sudo ./scripts/analyze-dns-packet-sizes.sh 8853 60
```

## Manual Monitoring Commands

### Using tcpdump

```bash
# Basic capture (all DNS traffic)
sudo tcpdump -i any -n -v port 8853 and udp

# Show packet sizes
sudo tcpdump -i any -n -v -s 0 port 8853 and udp | grep -E "length|>"

# Save to file for analysis
sudo tcpdump -i any -n -w /tmp/dns-capture.pcap port 8853 and udp

# Read from file
tcpdump -r /tmp/dns-capture.pcap -n -v
```

### Using tshark (Wireshark CLI)

```bash
# Real-time capture with packet details
sudo tshark -i any -f "udp port 8853" -T fields -e frame.len -e dns.qry.name

# Show DNS query names and sizes
sudo tshark -i any -f "udp port 8853" -T fields \
  -e frame.number \
  -e frame.len \
  -e dns.qry.name \
  -e dns.qry.type
```

### Using wireshark (GUI)

```bash
# Start Wireshark
sudo wireshark -i any -f "udp port 8853"

# Filter in Wireshark:
# - dns.qry.name contains "example.com"
# - frame.len < 512
# - dns.flags.response == 0  (queries only)
```

## Viewing MTU/Frame Sizes

### Client Side

The client now prints MTU information on startup:

```
Using MTU: 150 bytes
Max subdomain length: 101 chars, max payload per DNS query: 63 bytes
```

### Server Side

The server prints MTU information on startup:

```
Server MTU: 900 bytes
Domain: example.com
Case normalization: enabled
```

## Analyzing Packet Sizes

### Extract Packet Sizes from tcpdump

```bash
# Get all packet sizes
sudo tcpdump -i any -n port 8853 and udp 2>&1 | \
  grep -oP 'length \K\d+' | \
  sort -n | \
  uniq -c
```

### Calculate Statistics

```bash
# Min/Max/Average packet size
sudo tcpdump -i any -n port 8853 and udp 2>&1 | \
  grep -oP 'length \K\d+' | \
  awk '{
    sum+=$1; 
    if(NR==1 || $1<min) min=$1; 
    if(NR==1 || $1>max) max=$1; 
    count++
  } 
  END {
    printf "Min: %d\nMax: %d\nAvg: %.1f\nCount: %d\n", min, max, sum/count, count
  }'
```

## Monitoring Subdomain Lengths

### Extract Subdomain from DNS Queries

```bash
# Show DNS query names (subdomain + domain)
sudo tcpdump -i any -n port 8853 and udp 2>&1 | \
  grep -oP 'A\? [^ ]+\.example\.com' | \
  sed 's/A? //' | \
  while read qname; do
    subdomain=$(echo "$qname" | sed 's/\.example\.com//')
    echo "Subdomain length: ${#subdomain} - $subdomain"
  done
```

### Check if Subdomain Length Exceeds Limit

```bash
# Alert if subdomain > 101 chars
sudo tcpdump -i any -n port 8853 and udp 2>&1 | \
  grep -oP 'A\? [^ ]+\.example\.com' | \
  sed 's/A? //' | \
  while read qname; do
    subdomain=$(echo "$qname" | sed 's/\.example\.com//')
    len=${#subdomain}
    if [ $len -gt 101 ]; then
      echo "⚠️  WARNING: Subdomain length $len exceeds 101: $subdomain"
    fi
  done
```

## Continuous Monitoring Script

Create a monitoring script that runs continuously:

```bash
#!/usr/bin/env bash
# continuous-monitor.sh

PORT=8853
DOMAIN="example.com"

while true; do
    echo "=== $(date) ==="
    sudo tcpdump -i any -n -c 10 port $PORT and udp 2>&1 | \
      grep -E "length|$DOMAIN" | \
      head -20
    sleep 5
done
```

## Understanding the Output

### MTU vs Actual Packet Size

- **MTU**: Maximum Transmission Unit - the maximum size QUIC will try to send
- **Actual DNS Packet Size**: Usually smaller due to:
  - DNS header overhead (~12 bytes)
  - Base32 encoding expansion (~1.6x)
  - Dot insertion (every 57 chars)
  - Domain suffix

### Example Calculation

For domain `example.com` (11 chars) with MTU 150:
- Max subdomain space: ~240 chars (253 - 11 - 2)
- Base32 encoding: 150 bytes → ~240 base32 chars
- With dots: ~244 chars total
- DNS packet: ~256 bytes

With `--max-subdomain-length 101`:
- Max payload: ~63 bytes
- Base32: ~101 chars
- DNS packet: ~113 bytes

## Troubleshooting

### No Packets Captured

1. Check if server is running: `netstat -ulnp | grep 8853`
2. Check firewall: `sudo ufw status`
3. Verify port: `sudo ss -ulnp | grep 8853`

### Packets Too Large

If you see packets > 512 bytes:
- DNS UDP limit is 512 bytes
- Check if EDNS0 is being used
- Verify MTU settings

### Subdomain Length Issues

If subdomains exceed your limit:
- Check client MTU calculation
- Verify `--max-subdomain-length` is working
- Check server logs for decode errors
