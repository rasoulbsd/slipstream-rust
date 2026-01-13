#!/usr/bin/env bash
RESOLVER="${1:-2.189.44.44:53}"
cargo run -p slipstream-client -- --tcp-listen-port 7000 --resolver "${RESOLVER}" --domain slipstream.meonme.ir
