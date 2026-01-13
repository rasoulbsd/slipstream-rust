# Docker Setup for Slipstream

This guide explains how to run slipstream-server and slipstream-client using Docker Compose.

## Prerequisites

- Docker and Docker Compose installed
- Git submodules initialized: `git submodule update --init --recursive`
- Certificates generated (see below)

## Quick Start

### 1. Generate Certificates

```bash
# Generate certificates for your domain
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout certs/key.pem -out certs/cert.pem -days 365 \
  -subj "/CN=slipstream.example.com"

# Or use the Python script
python3 generate_certs.py
mkdir -p certs
mv .github/certs/*.pem certs/
```

### 2. Start Services

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Services

- **server**: slipstream-server listening on UDP 53 (DNS) and forwarding to TCP 5201
- **client**: slipstream-client listening on TCP 7000
- **echo**: TCP echo server for testing (listens on 5201)

## Configuration

### Environment Variables

Edit `docker-compose.yml` or create `docker-compose.override.yml`:

```yaml
services:
  server:
    environment:
      - DOMAIN=slipstream.example.com
      - DNS_LISTEN_PORT=53
      - TARGET_ADDRESS=echo:5201
  
  client:
    environment:
      - DOMAIN=slipstream.example.com
      - RESOLVER=server:53
      - TCP_LISTEN_PORT=7000
```

### Custom Commands

Override the default command in `docker-compose.override.yml`:

```yaml
services:
  server:
    command: ["/app/slipstream-server", "--dns-listen-port", "53", "--target-address", "echo:5201", "--domain", "yourdomain.com", "--cert", "/app/certs/cert.pem", "--key", "/app/certs/key.pem"]
  
  client:
    command: ["/app/slipstream-client", "--tcp-listen-port", "7000", "--resolver", "1.1.1.1:53", "--domain", "yourdomain.com"]
```

## Testing

```bash
# Test the connection
echo "Hello, Slipstream!" | nc localhost 7000

# Or send larger data
base64 /dev/urandom | head -c 1000000 | nc localhost 7000
```

## Ports

- **53/udp**: DNS server (slipstream-server)
- **5201/tcp**: Target service (echo server)
- **7000/tcp**: Client TCP listener (slipstream-client)

## Troubleshooting

### Certificates Missing

```bash
mkdir -p certs
# Generate certificates (see above)
```

### Port Already in Use

Edit `docker-compose.yml` to use different ports:

```yaml
services:
  server:
    ports:
      - "8853:53/udp"  # Use non-standard port
```

### Build Issues

```bash
# Clean build
docker-compose build --no-cache

# Check logs
docker-compose logs server
docker-compose logs client
```

## Production Notes

- Use proper TLS certificates (Let's Encrypt)
- Configure firewall rules
- Set up log rotation
- Use secrets management for certificates
- Consider using Docker secrets for certificate files
