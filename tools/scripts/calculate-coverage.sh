#!/usr/bin/env bash
# Coverage Calculator
# Aggregates all coverage metrics into a single percentage
#
# Exit codes:
#   0 - Coverage acceptable
#   1 - Calculation failed
#
# Usage:
#   ./calculate-coverage.sh              # Calculate and display coverage
#   ./calculate-coverage.sh --json       # Output JSON only

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
OUTPUT_DIR=".quality-metrics"
JSON_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_ONLY=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Calculates aggregate test coverage metrics."
      echo ""
      echo "Options:"
      echo "  --json     Output JSON only (no human-readable output)"
      echo "  -h, --help Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"
mkdir -p "$OUTPUT_DIR"

# Run namaka coverage if not already done
if [ ! -f "$OUTPUT_DIR/coverage.json" ]; then
  if [ "$JSON_ONLY" = false ]; then
    echo "Running coverage analysis..."
  fi
  ./tools/scripts/namaka-coverage-report.sh --report >/dev/null 2>&1 || true
fi

# Read coverage metrics
if [ -f "$OUTPUT_DIR/coverage.json" ]; then
  critical_coverage=$(jq -r '.critical_path_coverage' "$OUTPUT_DIR/coverage.json")
  test_suites=$(jq -r '.test_suites' "$OUTPUT_DIR/coverage.json")
  snapshot_assertions=$(jq -r '.snapshot_assertions' "$OUTPUT_DIR/coverage.json")
  hosts_tested=$(jq -r '.hosts_tested' "$OUTPUT_DIR/coverage.json")
  hosts_total=$(jq -r '.hosts_total' "$OUTPUT_DIR/coverage.json")
else
  critical_coverage=0
  test_suites=0
  snapshot_assertions=0
  hosts_tested=0
  hosts_total=5
fi

# Calculate host coverage percentage
if [ "$hosts_total" -gt 0 ]; then
  host_coverage=$((hosts_tested * 100 / hosts_total))
else
  host_coverage=0
fi

# Calculate module coverage (rough estimate based on test suites)
total_module_files=$(find modules/system modules/home -name '*.nix' ! -name 'default.nix' | wc -l)
# Estimate: each test suite covers ~5 modules on average
estimated_modules_covered=$((test_suites * 5))
if [ "$estimated_modules_covered" -gt "$total_module_files" ]; then
  estimated_modules_covered=$total_module_files
fi

if [ "$total_module_files" -gt 0 ]; then
  module_coverage=$((estimated_modules_covered * 100 / total_module_files))
else
  module_coverage=0
fi

# Aggregate coverage (weighted average):
# Critical paths: 50% weight
# Hosts: 30% weight
# Modules: 20% weight
aggregate_coverage=$(echo "scale=0; ($critical_coverage * 0.5) + ($host_coverage * 0.3) + ($module_coverage * 0.2)" | bc | cut -d. -f1)

# Generate output
if [ "$JSON_ONLY" = true ]; then
  cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "aggregate_coverage": $aggregate_coverage,
  "critical_path_coverage": $critical_coverage,
  "host_coverage": $host_coverage,
  "module_coverage": $module_coverage,
  "test_suites": $test_suites,
  "snapshot_assertions": $snapshot_assertions,
  "hosts_tested": $hosts_tested,
  "hosts_total": $hosts_total
}
EOF
else
  echo "📊 Coverage Summary"
  echo ""
  echo "Aggregate Coverage: ${aggregate_coverage}%"
  echo ""
  echo "Breakdown:"
  echo "  Critical Paths: ${critical_coverage}% (weight: 50%)"
  echo "  Hosts: ${host_coverage}% ($hosts_tested/$hosts_total tested, weight: 30%)"
  echo "  Modules: ${module_coverage}% (~$estimated_modules_covered/$total_module_files covered, weight: 20%)"
  echo ""
  echo "Test Metrics:"
  echo "  Test Suites: $test_suites"
  echo "  Snapshot Assertions: $snapshot_assertions"

  # Save to file
  cat > "$OUTPUT_DIR/aggregate-coverage.json" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "aggregate_coverage": $aggregate_coverage,
  "critical_path_coverage": $critical_coverage,
  "host_coverage": $host_coverage,
  "module_coverage": $module_coverage,
  "test_suites": $test_suites,
  "snapshot_assertions": $snapshot_assertions,
  "hosts_tested": $hosts_tested,
  "hosts_total": $hosts_total
}
EOF

  echo ""
  echo "📊 Metrics written to: $OUTPUT_DIR/aggregate-coverage.json"
fi

exit 0
