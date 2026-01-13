#!/usr/bin/env python3
"""Test multiple DNS resolvers to see which ones work with slipstream-client."""

import subprocess
import sys
import time
import signal
import os
from pathlib import Path

ROOT_DIR = Path(__file__).parent.parent
DOMAIN = os.environ.get("DOMAIN", "slipstream.meonme.ir")
TCP_PORT = int(os.environ.get("TCP_PORT", "7000"))
TEST_TIMEOUT = int(os.environ.get("TEST_TIMEOUT", "10"))

# Default resolvers to test
DEFAULT_RESOLVERS = [
    "1.1.1.1:53",
    "8.8.8.8:53",
    "2.189.44.44:53",
    "77.42.91.123:53",
]


def find_client_binary():
    """Find the slipstream-client binary."""
    release_bin = ROOT_DIR / "target" / "release" / "slipstream-client"
    debug_bin = ROOT_DIR / "target" / "debug" / "slipstream-client"
    
    if release_bin.exists():
        return str(release_bin)
    elif debug_bin.exists():
        return str(debug_bin)
    else:
        print("Building slipstream-client...")
        subprocess.run(["cargo", "build", "-p", "slipstream-client"], check=True)
        if debug_bin.exists():
            return str(debug_bin)
        raise FileNotFoundError("Could not find or build slipstream-client")


def test_resolver(client_bin, resolver):
    """Test a single resolver and return True if it works."""
    print(f"Testing resolver: {resolver}...", end=" ", flush=True)
    
    cmd = [
        client_bin,
        "--tcp-listen-port", str(TCP_PORT),
        "--resolver", resolver,
        "--domain", DOMAIN,
    ]
    
    try:
        # Start the client process
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        
        # Wait a bit for connection to establish
        time.sleep(3)
        
        # Check output for "Connection ready"
        output_lines = []
        start_time = time.time()
        
        while time.time() - start_time < TEST_TIMEOUT:
            if process.poll() is not None:
                # Process ended, read remaining output
                output_lines.extend(process.stdout.readlines())
                break
            
            # Try to read a line (non-blocking)
            try:
                line = process.stdout.readline()
                if line:
                    output_lines.append(line)
                    if "Connection ready" in line:
                        process.terminate()
                        try:
                            process.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            process.kill()
                        print("✓ SUCCESS - Connection ready!")
                        return True
            except:
                time.sleep(0.1)
        
        # Process didn't show "Connection ready" in time
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
        
        print("✗ FAILED - No connection ready message")
        return False
        
    except Exception as e:
        print(f"✗ ERROR - {e}")
        return False


def main():
    """Main function."""
    resolvers = sys.argv[1:] if len(sys.argv) > 1 else DEFAULT_RESOLVERS
    
    print("=== Testing Slipstream DNS Resolvers ===")
    print(f"Domain: {DOMAIN}")
    print(f"TCP Port: {TCP_PORT}")
    print(f"Test Timeout: {TEST_TIMEOUT}s")
    print(f"Resolvers to test: {len(resolvers)}")
    print()
    
    try:
        client_bin = find_client_binary()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    
    working = []
    failed = []
    
    for resolver in resolvers:
        if test_resolver(client_bin, resolver):
            working.append(resolver)
        else:
            failed.append(resolver)
        time.sleep(1)  # Small delay between tests
    
    print()
    print("=== Test Results ===")
    print()
    print(f"Working resolvers ({len(working)}):")
    if not working:
        print("  None")
    else:
        for resolver in working:
            print(f"  ✓ {resolver}")
    
    print()
    print(f"Failed resolvers ({len(failed)}):")
    if not failed:
        print("  None")
    else:
        for resolver in failed:
            print(f"  ✗ {resolver}")
    
    print()
    if working:
        print(f"Recommended resolver: {working[0]}")
        print()
        print("Use it with:")
        print(f"  cargo run -p slipstream-client -- \\")
        print(f"    --tcp-listen-port {TCP_PORT} \\")
        print(f"    --resolver {working[0]} \\")
        print(f"    --domain {DOMAIN}")
    
    return 0 if working else 1


if __name__ == "__main__":
    sys.exit(main())
