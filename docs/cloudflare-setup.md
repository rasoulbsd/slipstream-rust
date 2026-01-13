# Setting up Slipstream with Cloudflare and Two Servers

This guide explains how to set up slipstream with your own domain behind Cloudflare, using separate client and server machines.

## Architecture Overview

```
[Client Machine] 
    ↓ TCP:7000
[slipstream-client] 
    ↓ DNS queries (TXT records)
[Cloudflare DNS / Custom DNS Resolver]
    ↓ DNS queries forwarded
[Server Machine]
    ↓ UDP:53 (DNS)
[slipstream-server]
    ↓ TCP:5201
[Target Service]
```

## Prerequisites

- Two servers: one for client, one for server
- Domain managed by Cloudflare
- Root/sudo access on both servers
- Firewall rules configured (UDP 53 on server, TCP 7000 on client)

## Step 1: DNS Configuration in Cloudflare

### Option A: Use Cloudflare DNS (Recommended for testing)

1. **Create a DNS A record** pointing to your server IP:
   - Type: `A`
   - Name: `slipstream` (or any subdomain)
   - IPv4 address: `<your-server-ip>`
   - Proxy status: **DNS only** (gray cloud) ⚠️ **Important: Disable proxy**
   - TTL: Auto or 300 seconds

2. **Note the domain**: You'll use `slipstream.yourdomain.com` (or just `yourdomain.com`)

⚠️ **Important**: Cloudflare's proxy (orange cloud) will interfere with DNS tunneling. You **must** use DNS-only mode (gray cloud).

### Option B: Use a Custom DNS Server (More reliable)

If Cloudflare's DNS proxy causes issues, set up your own DNS server on the server machine:

1. Install a DNS server (BIND, PowerDNS, etc.)
2. Point your domain's NS records to your DNS server
3. Or use a subdomain with its own nameservers

## Step 2: Server Setup

On your **server machine**:

### 2.1 Generate TLS Certificates

```bash
# Generate certificate for your domain
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout key.pem -out cert.pem -days 365 \
  -subj "/CN=slipstream.yourdomain.com"
```

### 2.2 Configure Firewall

```bash
# Allow UDP port 53 (DNS)
sudo ufw allow 53/udp
# Or if using custom port:
sudo ufw allow 8853/udp
```

### 2.3 Run the Server

```bash
# If using standard DNS port (requires root or capabilities)
sudo ./target/release/slipstream-server \
  --dns-listen-port 53 \
  --target-address 127.0.0.1:5201 \
  --domain slipstream.yourdomain.com \
  --cert ./cert.pem \
  --key ./key.pem

# Or use a non-privileged port (e.g., 8853)
./target/release/slipstream-server \
  --dns-listen-port 8853 \
  --target-address 127.0.0.1:5201 \
  --domain slipstream.yourdomain.com \
  --cert ./cert.pem \
  --key ./key.pem
```

**Note**: If using port 53, you may need to:
- Run with `sudo`
- Or set capabilities: `sudo setcap 'cap_net_bind_service=+ep' target/release/slipstream-server`

### 2.4 Start Target Service (for testing)

```bash
# Start echo server on port 5201
python3 scripts/interop/tcp_echo.py --listen 127.0.0.1:5201
```

## Step 3: Client Setup

On your **client machine**:

### 3.1 Configure Firewall

```bash
# Allow TCP port 7000 (or your chosen port)
sudo ufw allow 7000/tcp
```

### 3.2 Run the Client

**If using Cloudflare DNS directly:**

```bash
./target/release/slipstream-client \
  --tcp-listen-port 7000 \
  --resolver 1.1.1.1:53 \
  --domain slipstream.yourdomain.com
```

**If using a custom DNS server or DNS forwarding:**

```bash
# Point to your server's DNS port
./target/release/slipstream-client \
  --tcp-listen-port 7000 \
  --resolver <server-ip>:53 \
  --domain slipstream.yourdomain.com
```

**If server uses non-standard port:**

```bash
./target/release/slipstream-client \
  --tcp-listen-port 7000 \
  --resolver <server-ip>:8853 \
  --domain slipstream.yourdomain.com
```

## Step 4: DNS Forwarding Setup (Alternative)

If Cloudflare DNS doesn't work well, you can set up DNS forwarding:

### On Server Machine:

1. Install a DNS forwarder (like `dnsmasq` or `unbound`)
2. Configure it to forward queries for your domain to `127.0.0.1:53` (where slipstream-server listens)
3. Point Cloudflare to your server's DNS

### Example with dnsmasq:

```bash
# Install dnsmasq
sudo apt-get install dnsmasq

# Configure /etc/dnsmasq.conf
server=/slipstream.yourdomain.com/127.0.0.1#53
listen-address=0.0.0.0

# Restart dnsmasq
sudo systemctl restart dnsmasq
```

Then point Cloudflare's NS records to your server, or use a subdomain.

## Step 5: Testing

### Test the connection:

```bash
# On client machine or any machine
echo "Hello, Slipstream!" | nc <client-ip> 7000

# Or send larger data
base64 /dev/urandom | head -c 1000000 | nc <client-ip> 7000
```

### Verify DNS queries are working:

```bash
# Check if DNS queries reach the server
dig @<server-ip> -p 53 TXT test.slipstream.yourdomain.com

# Monitor DNS traffic on server
sudo tcpdump -i any -n udp port 53
```

## Troubleshooting

### Issue: "Connection refused" on server

- Check firewall: `sudo ufw status`
- Verify server is listening: `sudo netstat -ulnp | grep 53`
- Check if port 53 requires root: try port 8853 instead

### Issue: DNS queries not reaching server

- Verify DNS record points to correct IP
- Check Cloudflare proxy is disabled (gray cloud)
- Test DNS resolution: `dig slipstream.yourdomain.com`
- Check firewall allows UDP 53

### Issue: Client can't connect

- Verify resolver IP/port is correct
- Test DNS resolution from client: `dig @1.1.1.1 slipstream.yourdomain.com`
- Check if Cloudflare is blocking/proxying DNS
- Try using server IP directly as resolver

### Issue: Slow performance

- Cloudflare's DNS proxy may add latency
- Consider using a custom DNS server
- Check network latency between client and server
- Monitor DNS query/response times

## Security Considerations

1. **TLS Certificates**: Use proper certificates for production (Let's Encrypt)
2. **Firewall**: Only open necessary ports
3. **DNS Security**: Consider DNS-over-HTTPS (DoH) or DNS-over-TLS (DoT) if needed
4. **Rate Limiting**: Cloudflare may rate-limit DNS queries
5. **Monitoring**: Set up logging and monitoring for both servers

## Advanced: Multiple Resolvers

The client supports multiple resolvers for redundancy:

```bash
./target/release/slipstream-client \
  --tcp-listen-port 7000 \
  --resolver 1.1.1.1:53 \
  --resolver 8.8.8.8:53 \
  --domain slipstream.yourdomain.com
```

## Production Recommendations

1. Use systemd services for auto-start
2. Set up log rotation
3. Use proper TLS certificates (Let's Encrypt)
4. Monitor DNS query rates and errors
5. Consider using a dedicated DNS server instead of Cloudflare for better control
