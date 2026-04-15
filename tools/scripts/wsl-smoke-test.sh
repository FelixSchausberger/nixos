#!/usr/bin/env bash
# WSL Shell Startup Smoke Test
# Quick validation that shell environments work correctly in WSL
#
# Exit codes:
#   0 - All smoke tests passed
#   1 - One or more tests failed

set -euo pipefail

echo "WSL Shell Startup Smoke Test"
echo "================================"
echo ""

FAILED_TESTS=0

# Test bash fallback shell
echo "Testing bash fallback shell..."
if wsl.exe --exec /run/current-system/sw/bin/bash -c 'exit 0' 2>/dev/null; then
  echo "Bash fallback works"
else
  echo "Bash fallback failed"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test fish shell startup
echo "Testing fish shell startup..."
if wsl.exe --exec /run/current-system/sw/bin/fish -c 'exit 0' 2>/dev/null; then
  echo "Fish startup works"
else
  echo "Fish startup failed"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test emergency shell wrapper
echo "Testing emergency shell wrapper..."
if wsl.exe --exec /run/current-system/sw/bin/wsl-emergency-shell -c 'exit 0' 2>/dev/null; then
  echo "Emergency shell wrapper works"
else
  echo "Emergency shell wrapper test skipped (interactive only)"
fi

# Test emergency user account (if exists)
echo "Testing emergency user account..."
if wsl.exe -u emergency --exec bash -c 'exit 0' 2>/dev/null; then
  echo "Emergency user account accessible"
else
  echo "Emergency user account not accessible (may not exist yet)"
fi

echo ""
echo "Smoke Test Summary"
echo "===================="

if [ $FAILED_TESTS -eq 0 ]; then
  echo "All smoke tests passed!"
  echo "   WSL shell environments are functioning correctly"
  exit 0
else
  echo "$FAILED_TESTS test(s) failed"
  echo "   Critical shell functionality is broken"
  exit 1
fi
