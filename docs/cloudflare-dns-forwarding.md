# Setting up External DNS Resolver with Cloudflare (Option 3)

This guide sets up a DNS forwarder that works with Cloudflare, allowing you to use public DNS resolvers while forwarding queries to your slipstream-server.

## Architecture

```
[Client] 
  ↓ DNS queries to 1.1.1.1 or your DNS server
[Cloudflare DNS / Your DNS Server]
  ↓ Queries for slipstream.meonme.ir
[DNS Forwarder on Server]
  ↓ Forwards to 127.0.0.1:53
[slipstream-server]
```

## Prerequisites

- Server machine with root/sudo access
- Port 53 available (or use a different port and configure accordingly)
- Domain managed by Cloudflare

## Step 1: Set up DNS Forwarder on Server

You have two options: **dnsmasq** (simpler) or **BIND9** (more robust).

### Option A: Using dnsmasq (Recommended for simplicity)

#### 1.1 Install dnsmasq

```bash
sudo apt-get update
sudo apt-get install dnsmasq
```

#### 1.2 Stop systemd-resolved (if running)

dnsmasq needs port 53, so we need to free it:

```bash
# Check if systemd-resolved is using port 53
sudo netstat -ulnp | grep :53

# Stop and disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Edit /etc/systemd/resolved.conf and set DNSStubListener=no
sudo nano /etc/systemd/resolved.conf
# Add or uncomment: DNSStubListener=no

# Restart systemd-resolved if needed
sudo systemctl restart systemd-resolved
```

#### 1.3 Configure dnsmasq

Edit `/etc/dnsmasq.conf`:

```bash
sudo nano /etc/dnsmasq.conf
```

Add or modify these settings:

```conf
# Listen on all interfaces
listen-address=0.0.0.0

# Port (default is 53)
port=53

# Forward queries for slipstream.meonme.ir to slipstream-server
server=/slipstream.meonme.ir/127.0.0.1#53

# Use upstream DNS for other queries
server=1.1.1.1
server=8.8.8.8

# Don't read /etc/resolv.conf
no-resolv

# Log queries (useful for debugging)
log-queries
log-facility=/var/log/dnsmasq.log
```

#### 1.4 Start dnsmasq

```bash
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# Check status
sudo systemctl status dnsmasq

# Check if it's listening
sudo netstat -ulnp | grep :53
```

### Option B: Using BIND9 (More robust, production-ready)

#### 1.1 Install BIND9

```bash
sudo apt-get update
sudo apt-get install bind9 bind9utils bind9-doc
```

#### 1.2 Configure BIND9

Edit `/etc/bind/named.conf.options`:

```bash
sudo nano /etc/bind/named.conf.options
```

```conf
options {
    directory "/var/cache/bind";
    
    // Forward queries for slipstream.meonme.ir to slipstream-server
    forwarders {
        127.0.0.1 port 53;  // slipstream-server
    };
    
    // For other domains, use public DNS
    forwarders {
        1.1.1.1;
        8.8.8.8;
    };
    
    // Allow queries from anywhere (adjust for security)
    allow-query { any; };
    
    // Listen on all interfaces
    listen-on { any; };
    listen-on-v6 { any; };
    
    // Enable recursion
    recursion yes;
    
    // Logging
    logging {
        channel default_log {
            file "/var/log/bind/named.log" versions 3 size 5m;
            severity dynamic;
        };
        category default { default_log; };
        category queries { default_log; };
    };
};
```

Create a zone file for forwarding:

Edit `/etc/bind/named.conf.local`:

```bash
sudo nano /etc/bind/named.conf.local
```

```conf
zone "slipstream.meonme.ir" {
    type forward;
    forwarders { 127.0.0.1 port 53; };
};
```

#### 1.3 Create log directory and start BIND9

```bash
sudo mkdir -p /var/log/bind
sudo chown bind:bind /var/log/bind

# Test configuration
sudo named-checkconf

# Start BIND9
sudo systemctl restart bind9
sudo systemctl enable bind9

# Check status
sudo systemctl status bind9
```

## Step 2: Configure Cloudflare DNS

You have two approaches:

### Approach 1: Use NS Record Delegation (Recommended)

1. Go to Cloudflare Dashboard → DNS
2. Add an **NS record**:
   - Type: `NS`
   - Name: `slipstream` (or leave blank for subdomain delegation)
   - Content: `ns.meonme.ir` (or your server's hostname)
   - TTL: Auto

3. Make sure you have an A record for `ns.meonme.ir` pointing to your server IP:
   - Type: `A`
   - Name: `ns`
   - Content: `77.42.91.123`
   - Proxy: DNS only (gray cloud)

### Approach 2: Use the DNS server directly (Simpler, but requires public IP)

If your DNS forwarder is accessible, clients can query it directly without going through Cloudflare.

## Step 3: Run slipstream-server

Make sure slipstream-server is running on port 53 (or the port your DNS forwarder points to):

```bash
# If using port 53, you may need to run with sudo or set capabilities
sudo ./target/release/slipstream-server \
  --dns-listen-port 53 \
  --target-address 127.0.0.1:5201 \
  --domain slipstream.meonme.ir \
  --cert ./cert.pem \
  --key ./key.pem
```

**Important**: If dnsmasq or BIND is using port 53, you have two options:

1. **Run slipstream-server on a different port** (e.g., 5353) and configure the forwarder to use that port:
   - dnsmasq: `server=/slipstream.meonme.ir/127.0.0.1#5353`
   - BIND: `forwarders { 127.0.0.1 port 5353; };`

2. **Run slipstream-server first**, then configure dnsmasq/BIND to forward to it (they'll need to use a different port or you'll need to coordinate)

## Step 4: Configure Client

Now you can use Cloudflare DNS or your DNS server:

```bash
# Using Cloudflare DNS (1.1.1.1)
./target/release/slipstream-client \
  --tcp-listen-port 7000 \
  --resolver 1.1.1.1:53 \
  --domain slipstream.meonme.ir

# OR using your DNS server directly
./target/release/slipstream-client \
  --tcp-listen-port 7000 \
  --resolver 77.42.91.123:53 \
  --domain slipstream.meonme.ir
```

## Step 5: Testing

### Test DNS resolution:

```bash
# Test from client machine
dig @1.1.1.1 slipstream.meonme.ir

# Test direct query to your DNS server
dig @77.42.91.123 slipstream.meonme.ir

# Test with a TXT query (what slipstream uses)
dig @77.42.91.123 TXT test.slipstream.meonme.ir
```

### Test the tunnel:

```bash
# Send test data
echo "Hello, Slipstream!" | nc <client-ip> 7000
```

### Monitor DNS queries:

```bash
# On server, monitor dnsmasq logs
sudo tail -f /var/log/dnsmasq.log

# Or monitor BIND logs
sudo tail -f /var/log/bind/named.log

# Monitor DNS traffic
sudo tcpdump -i any -n udp port 53
```

## Troubleshooting

### Issue: Port 53 already in use

```bash
# Check what's using port 53
sudo netstat -ulnp | grep :53
sudo ss -ulnp | grep :53

# Stop conflicting services
sudo systemctl stop systemd-resolved
# Or configure slipstream-server to use a different port
```

### Issue: DNS queries not reaching slipstream-server

1. Check dnsmasq/BIND configuration points to correct port
2. Verify slipstream-server is listening: `sudo netstat -ulnp | grep 53`
3. Test direct query: `dig @127.0.0.1 -p 53 TXT test.slipstream.meonme.ir`
4. Check firewall allows UDP 53

### Issue: Cloudflare not forwarding queries

- Verify NS records are set correctly
- Check that `ns.meonme.ir` A record points to server IP
- Test DNS delegation: `dig @1.1.1.1 NS slipstream.meonme.ir`
- Cloudflare may cache responses; wait for TTL to expire

### Issue: dnsmasq/BIND conflicts with slipstream-server

**Solution**: Run slipstream-server on port 5353, configure forwarder to use that:

```bash
# dnsmasq config
server=/slipstream.meonme.ir/127.0.0.1#5353

# Run slipstream-server
./target/release/slipstream-server \
  --dns-listen-port 5353 \
  --domain slipstream.meonme.ir \
  --cert ./cert.pem \
  --key ./key.pem
```

## Security Considerations

1. **Firewall**: Only allow DNS (UDP 53) from trusted sources if possible
2. **Rate Limiting**: Configure dnsmasq/BIND rate limiting to prevent abuse
3. **Access Control**: Restrict which IPs can query your DNS server
4. **Monitoring**: Set up logging and monitoring for unusual activity

## Advanced: Multiple DNS Servers

For redundancy, you can set up multiple DNS forwarders:

1. Set up DNS forwarder on multiple servers
2. Configure multiple NS records in Cloudflare
3. Client can use multiple resolvers: `--resolver 1.1.1.1:53 --resolver 8.8.8.8:53`

## Notes

- Cloudflare may cache DNS responses, which can cause delays
- NS record delegation may take time to propagate
- For best performance, query the DNS forwarder directly instead of going through Cloudflare
- This setup is more complex but allows using public DNS resolvers
