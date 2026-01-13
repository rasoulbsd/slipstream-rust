#!/usr/bin/env python3
"""Test your specific list of DNS resolvers."""

import subprocess
import sys
import time
import os
from pathlib import Path

ROOT_DIR = Path(__file__).parent.parent
DOMAIN = os.environ.get("DOMAIN", "slipstream.example.com")
TCP_PORT = int(os.environ.get("TCP_PORT", "7000"))
TEST_TIMEOUT = int(os.environ.get("TEST_TIMEOUT", "15"))
CONNECTION_WAIT = int(os.environ.get("CONNECTION_WAIT", "7"))

# Your resolver list
RESOLVERS = [
    "2.188.21.20:53",
    "2.188.21.90:53",
    "2.188.21.100:53",
    "2.188.21.120:53",
    "2.188.21.130:53",
    "2.188.21.190:53",
    "2.188.21.200:53",
    "2.188.21.230:53",
    "2.188.21.240:53",
    "2.189.44.44:53",
    "37.152.190.80:53",
    "95.38.94.218:53",
    "217.218.26.77:53",
    "217.218.26.78:53",
    "217.218.127.126:53",
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
        
        # Wait and check continuously for connection to establish (up to CONNECTION_WAIT seconds)
        output_lines = []
        start_time = time.time()
        connection_wait_end = start_time + CONNECTION_WAIT
        
        while time.time() < connection_wait_end:
            if process.poll() is not None:
                # Process ended, read remaining output
                remaining = process.stdout.read()
                if remaining:
                    output_lines.append(remaining)
                break
            
            # Try to read a line (non-blocking)
            try:
                # Set non-blocking mode
                import select
                if select.select([process.stdout], [], [], 0.1)[0]:
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
            except (OSError, ValueError):
                # Fallback if select doesn't work
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
                    pass
            time.sleep(0.5)  # Check every 0.5 seconds
        
        # Process didn't show "Connection ready" in time
        # Final check - read any remaining output
        try:
            remaining = process.stdout.read()
            if remaining:
                output_lines.append(remaining)
                if "Connection ready" in remaining:
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                    print("✓ SUCCESS - Connection ready! (detected on final check)")
                    return True
        except:
            pass
        
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
        
        print(f"✗ FAILED - No connection ready message after {CONNECTION_WAIT}s")
        if output_lines:
            print(f"    Last output: {output_lines[-1][:100] if output_lines[-1] else 'empty'}")
        return False
        
    except Exception as e:
        print(f"✗ ERROR - {e}")
        return False


def main():
    """Main function."""
    print("=== Testing Slipstream DNS Resolvers ===")
    print(f"Domain: {DOMAIN}")
    print(f"TCP Port: {TCP_PORT}")
    print(f"Test Timeout: {TEST_TIMEOUT}s")
    print(f"Connection Wait: {CONNECTION_WAIT}s")
    print(f"Resolvers to test: {len(RESOLVERS)}")
    print()
    
    try:
        client_bin = find_client_binary()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    
    working = []
    failed = []
    
    for resolver in RESOLVERS:
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
