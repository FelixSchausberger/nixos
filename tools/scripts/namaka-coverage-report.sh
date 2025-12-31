#!/usr/bin/env bash
# Namaka Coverage Reporter
# Analyzes test coverage by comparing evaluated options in tests vs actual configurations
#
# Exit codes:
#   0 - Coverage meets threshold
#   1 - Coverage below threshold or analysis failed
#
# Usage:
#   ./namaka-coverage-report.sh                    # Check coverage (fail if <100% critical)
#   ./namaka-coverage-report.sh --threshold 80     # Custom threshold
#   ./namaka-coverage-report.sh --report           # Generate detailed report

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
THRESHOLD=100  # Default: 100% critical path coverage required
REPORT_MODE=false
OUTPUT_DIR=".quality-metrics"

# Critical paths that must be tested
CRITICAL_PATHS=(
  "boot"
  "networking"
  "users"
  "security"
  "systemd.services"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    --report)
      REPORT_MODE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Analyzes test coverage for NixOS configuration."
      echo ""
      echo "Options:"
      echo "  --threshold N    Set coverage threshold percentage (default: 100)"
      echo "  --report         Generate detailed coverage report"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "🔍 Analyzing test coverage..."

# Count test suites
test_suites=$(find tests -mindepth 1 -maxdepth 1 -type d | wc -l)
echo "Found $test_suites test suites"

# Count snapshot assertions
if [ -d "tests/_snapshots" ]; then
  snapshot_files=$(find tests/_snapshots -name '*.nix' | wc -l)
  echo "Found $snapshot_files snapshot assertions"
else
  snapshot_files=0
  echo "Warning: No snapshots directory found" >&2
fi

# Count hosts with tests
hosts_with_tests=$(find tests -maxdepth 1 -type d -name 'hosts-*' | wc -l)
total_hosts=$(find hosts -mindepth 1 -maxdepth 1 -type d ! -name 'installer*' ! -name 'default.nix' | wc -l)
echo "Host coverage: $hosts_with_tests/$total_hosts hosts tested"

# Count modules
total_modules=$(find modules/system modules/home -name '*.nix' ! -name 'default.nix' | wc -l)
echo "Total modules: $total_modules"

# Check critical path coverage
critical_coverage=0
critical_total=${#CRITICAL_PATHS[@]}
critical_missing=()

for path in "${CRITICAL_PATHS[@]}"; do
  # Search test files for references to critical paths
  if git grep -q "config\.$path" tests/ 2>/dev/null; then
    ((critical_coverage++)) || true
  else
    critical_missing+=("$path")
  fi
done

critical_percent=$((critical_coverage * 100 / critical_total))

echo ""
echo "📊 Coverage Summary:"
echo "  Critical Paths: $critical_coverage/$critical_total ($critical_percent%)"
echo "  Test Suites: $test_suites"
echo "  Snapshot Assertions: $snapshot_files"
echo "  Host Coverage: $hosts_with_tests/$total_hosts"

# Generate detailed report if requested
if [ "$REPORT_MODE" = true ]; then
  report_file="$OUTPUT_DIR/coverage-report.md"

  cat > "$report_file" <<EOF
# Test Coverage Report

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Summary

- **Critical Path Coverage**: $critical_percent% ($critical_coverage/${critical_total})
- **Test Suites**: $test_suites
- **Snapshot Assertions**: $snapshot_files
- **Host Coverage**: $hosts_with_tests/$total_hosts hosts

## Critical Paths Coverage

EOF

  for path in "${CRITICAL_PATHS[@]}"; do
    if git grep -q "config\.$path" tests/ 2>/dev/null; then
      echo "- ✅ \`$path\` - Covered" >> "$report_file"
    else
      echo "- ❌ \`$path\` - Not covered" >> "$report_file"
    fi
  done

  cat >> "$report_file" <<EOF

## Test Suites

EOF

  for suite in tests/*/; do
    suite_name=$(basename "$suite")
    if [ -f "$suite/expr.nix" ]; then
      echo "- $suite_name" >> "$report_file"
    fi
  done

  echo ""
  echo "📝 Detailed report written to: $report_file"
fi

# Generate JSON metrics for CI
json_file="$OUTPUT_DIR/coverage.json"
cat > "$json_file" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "critical_path_coverage": $critical_percent,
  "critical_paths_covered": $critical_coverage,
  "critical_paths_total": $critical_total,
  "test_suites": $test_suites,
  "snapshot_assertions": $snapshot_files,
  "hosts_tested": $hosts_with_tests,
  "hosts_total": $total_hosts,
  "total_modules": $total_modules
}
EOF

echo "📊 Metrics written to: $json_file"
echo ""

# Check threshold
if [ "$critical_percent" -lt "$THRESHOLD" ]; then
  echo "❌ Critical path coverage ($critical_percent%) below threshold ($THRESHOLD%)"
  if [ ${#critical_missing[@]} -gt 0 ]; then
    echo ""
    echo "Missing coverage for critical paths:"
    for path in "${critical_missing[@]}"; do
      echo "  • config.$path"
    done
  fi
  exit 1
fi

echo "✅ Coverage meets threshold ($critical_percent% >= $THRESHOLD%)"
exit 0
