#!/bin/bash
set -e

if [ "$1" = "server" ]; then
    exec /app/slipstream-server \
        --dns-listen-port "${DNS_LISTEN_PORT:-53}" \
        --target-address "${TARGET_ADDRESS:-127.0.0.1:5201}" \
        --domain "${DOMAIN:-slipstream.meonme.ir}" \
        --cert "${CERT_PATH:-/app/certs/cert.pem}" \
        --key "${KEY_PATH:-/app/certs/key.pem}"
elif [ "$1" = "client" ]; then
    exec /app/slipstream-client \
        --tcp-listen-port "${TCP_LISTEN_PORT:-7000}" \
        --resolver "${RESOLVER:-server:53}" \
        --domain "${DOMAIN:-slipstream.meonme.ir}"
else
    exec "$@"
fi
