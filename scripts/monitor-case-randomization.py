#!/usr/bin/env python3
"""
Monitor DNS queries for case randomization patterns.
This script captures DNS traffic and analyzes case distribution.
"""

import sys
import argparse
import subprocess
import re
from collections import defaultdict
from datetime import datetime

def analyze_dns_query(qname):
    """Analyze a DNS query name for case patterns."""
    if not qname:
        return None
    
    # Extract subdomain (before the domain)
    parts = qname.lower().rsplit('.', 2)
    if len(parts) < 2:
        return None
    
    subdomain = parts[0]
    domain = '.'.join(parts[1:])
    
    # Count case variations
    upper_count = sum(1 for c in subdomain if c.isupper())
    lower_count = sum(1 for c in subdomain if c.islower())
    mixed = upper_count > 0 and lower_count > 0
    
    return {
        'qname': qname,
        'subdomain': subdomain,
        'domain': domain,
        'upper_count': upper_count,
        'lower_count': lower_count,
        'mixed_case': mixed,
        'total_alpha': upper_count + lower_count,
        'case_ratio': upper_count / (upper_count + lower_count) if (upper_count + lower_count) > 0 else 0,
    }

def capture_with_tcpdump(interface, domain, duration=60):
    """Capture DNS queries using tcpdump."""
    print(f"Capturing DNS queries for domain '{domain}' on interface {interface} for {duration} seconds...")
    print("(Requires root/sudo privileges)")
    
    # Build tcpdump filter
    filter_expr = f"udp port 53 and host {domain.split('.')[0]}"
    
    cmd = [
        'tcpdump',
        '-i', interface,
        '-n',  # Don't resolve addresses
        '-l',  # Line buffered
        '-A',  # Print ASCII
        '-s', '0',  # Snapshot length
        filter_expr,
    ]
    
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        queries = []
        start_time = datetime.now()
        
        for line in process.stdout:
            if (datetime.now() - start_time).seconds > duration:
                process.terminate()
                break
            
            # Extract DNS query name from tcpdump output
            # Look for patterns like "A? example.com"
            match = re.search(r'(\S+\.\S+\.)', line)
            if match:
                qname = match.group(1).rstrip('.')
                if domain.lower() in qname.lower():
                    queries.append(qname)
        
        process.wait()
        return queries
    
    except FileNotFoundError:
        print("Error: tcpdump not found. Install with: sudo apt-get install tcpdump")
        return []
    except PermissionError:
        print("Error: Permission denied. Run with sudo.")
        return []

def analyze_queries(queries, domain):
    """Analyze captured queries for case patterns."""
    if not queries:
        print("No queries captured.")
        return
    
    print(f"\n=== Analysis of {len(queries)} DNS queries ===\n")
    
    analyses = []
    for qname in queries:
        analysis = analyze_dns_query(qname)
        if analysis:
            analyses.append(analysis)
    
    if not analyses:
        print("No valid queries found.")
        return
    
    # Statistics
    mixed_case_count = sum(1 for a in analyses if a['mixed_case'])
    all_upper = sum(1 for a in analyses if a['upper_count'] > 0 and a['lower_count'] == 0)
    all_lower = sum(1 for a in analyses if a['lower_count'] > 0 and a['upper_count'] == 0)
    
    print(f"Total queries analyzed: {len(analyses)}")
    print(f"Mixed case queries: {mixed_case_count} ({mixed_case_count/len(analyses)*100:.1f}%)")
    print(f"All uppercase: {all_upper} ({all_upper/len(analyses)*100:.1f}%)")
    print(f"All lowercase: {all_lower} ({all_lower/len(analyses)*100:.1f}%)")
    
    if mixed_case_count > 0:
        print("\n⚠️  WARNING: Case randomization detected!")
        print("   This suggests DNS queries are being modified (e.g., by GFW)")
        print("   Consider enabling --normalize-case on the server")
    else:
        print("\n✓ No case randomization detected")
    
    # Show examples
    if mixed_case_count > 0:
        print("\nExample mixed-case queries:")
        for a in analyses[:5]:
            if a['mixed_case']:
                print(f"  {a['qname']}")
                print(f"    Case ratio: {a['case_ratio']:.2%} uppercase")

def main():
    parser = argparse.ArgumentParser(description='Monitor DNS queries for case randomization')
    parser.add_argument('--domain', required=True, help='Domain to monitor')
    parser.add_argument('--interface', default='any', help='Network interface (default: any)')
    parser.add_argument('--duration', type=int, default=60, help='Capture duration in seconds (default: 60)')
    parser.add_argument('--file', help='Read queries from file (one per line) instead of capturing')
    
    args = parser.parse_args()
    
    if args.file:
        print(f"Reading queries from {args.file}...")
        with open(args.file, 'r') as f:
            queries = [line.strip() for line in f if line.strip()]
    else:
        queries = capture_with_tcpdump(args.interface, args.domain, args.duration)
    
    analyze_queries(queries, args.domain)

if __name__ == '__main__':
    main()
