#!/usr/bin/env python3
"""
Run Mojo tests individually and classify them by execution time.

This script collects all tests, runs them one by one, measures their execution time,
and then displays them sorted from slowest to fastest.
"""

import subprocess
import time
import re
import sys
from typing import List, Tuple
import os

def get_all_tests() -> List[str]:
    """Collect all test names using mojo test --collect-only."""
    result = subprocess.run(
        ["pixi", "run", "mojo", "test", "-I", "./src", "tests/", "--collect-only"],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print("Error collecting tests:")
        print(result.stderr)
        sys.exit(1)
    
    # Parse test names from the output
    tests = []
    for line in result.stdout.splitlines():
        # Match lines that contain test paths
        match = re.search(r'tests/.*\.mojo::test_.*\(\)', line)
        if match:
            tests.append(match.group())
    
    return tests

def run_single_test(test_path: str) -> Tuple[bool, float, str]:
    """
    Run a single test and return (success, duration, output).
    
    Args:
        test_path: The test path in format "tests/file.mojo::test_name()"
    
    Returns:
        Tuple of (success, duration_in_seconds, output)
    """
    
    result = subprocess.run(
        ["pixi", "run", "mojo", "test", "-I", "./src", test_path],
        capture_output=True,
        text=True
    )
    
    first_line = result.stdout.splitlines()[0]
    duration = float(first_line.split(" ")[-1].removesuffix("s"))
    success = result.returncode == 0
    output = result.stdout if success else result.stderr
    
    return success, duration, output

def format_duration(seconds: float) -> str:
    """Format duration in a human-readable way."""
    if seconds < 1:
        return f"{seconds*1000:.0f}ms"
    elif seconds < 60:
        return f"{seconds:.2f}s"
    else:
        minutes = int(seconds // 60)
        secs = seconds % 60
        return f"{minutes}m {secs:.1f}s"

def main():
    """Main function to run all tests and display results."""
    print("Collecting tests...")
    tests = get_all_tests()
    print(f"Found {len(tests)} tests\n")
    
    if not tests:
        print("No tests found!")
        sys.exit(1)
    
    print("Running tests individually...\n")
    
    results = []
    passed = 0
    failed = 0
    
    for i, test in enumerate(tests, 1):
        # Extract just the test name for display
        test_name = test.split("::")[-1].rstrip("()")
        test_file = test.split("/")[-1].split("::")[0]
        
        print(f"[{i}/{len(tests)}] Running {test_file}::{test_name}...", end="", flush=True)
        
        success, duration, output = run_single_test(test)
        
        if success:
            print(f" ✓ ({format_duration(duration)})")
            passed += 1
        else:
            print(f" ✗ ({format_duration(duration)})")
            failed += 1
            # Print error output for failed tests
            print(f"  Error output:")
            for line in output.splitlines()[-10:]:  # Last 10 lines of error
                print(f"    {line}")
        
        results.append((test, success, duration))
    
    # Sort by duration (slowest first)
    results.sort(key=lambda x: x[2], reverse=True)
    
    print("\n" + "="*80)
    print("TEST RESULTS SORTED BY EXECUTION TIME (SLOWEST TO FASTEST)")
    print("="*80)
    print(f"{'Rank':<6} {'Duration':<10} {'Status':<8} {'Test'}")
    print("-"*80)
    
    for rank, (test, success, duration) in enumerate(results, 1):
        status = "PASS" if success else "FAIL"
        status_color = "\033[92m" if success else "\033[91m"  # Green for pass, red for fail
        reset_color = "\033[0m"
        
        # Extract test name for display
        test_display = test.replace("tests/", "")
        
        print(f"{rank:<6} {format_duration(duration):<10} {status_color}{status:<8}{reset_color} {test_display}")
    
    print("-"*80)
    print(f"Total: {len(tests)} tests | Passed: {passed} | Failed: {failed}")
    print(f"Total execution time: {format_duration(sum(r[2] for r in results))}")
    # Return exit code based on test results
    sys.exit(0 if failed == 0 else 1)

if __name__ == "__main__":
    main()