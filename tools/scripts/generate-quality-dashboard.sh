#!/usr/bin/env bash
# Quality Dashboard Generator
# Aggregates all quality metrics into a comprehensive markdown dashboard
#
# Exit codes:
#   0 - Dashboard generated successfully
#   1 - Generation failed
#
# Usage:
#   ./generate-quality-dashboard.sh              # Generate dashboard
#   ./generate-quality-dashboard.sh --output FILE # Custom output location

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
OUTPUT_FILE="docs/QUALITY_DASHBOARD.md"
METRICS_DIR=".quality-metrics"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Generates comprehensive quality dashboard."
      echo ""
      echo "Options:"
      echo "  --output FILE  Output file path (default: docs/QUALITY_DASHBOARD.md)"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"
mkdir -p "$(dirname "$OUTPUT_FILE")"
mkdir -p "$METRICS_DIR"

echo "📊 Generating quality dashboard..."

# Run all metric collection scripts
echo "Collecting metrics..."

# Coverage metrics
if [ -x "tools/scripts/namaka-coverage-report.sh" ]; then
  ./tools/scripts/namaka-coverage-report.sh --report >/dev/null 2>&1 || true
fi

if [ -x "tools/scripts/calculate-coverage.sh" ]; then
  ./tools/scripts/calculate-coverage.sh >/dev/null 2>&1 || true
fi

# Code quality metrics
if [ -x "tools/scripts/detect-unused-modules.sh" ]; then
  unused_modules=0
  if ! ./tools/scripts/detect-unused-modules.sh >/dev/null 2>&1; then
    # Count how many unused modules were found
    unused_output=$(./tools/scripts/detect-unused-modules.sh 2>&1 || true)
    unused_modules=$(echo "$unused_output" | grep -c "• " || echo "0")
  fi
else
  unused_modules="N/A"
fi

# Deadnix check
deadnix_issues=$(deadnix --fail . 2>&1 | grep -c "\.nix" || echo "0")

# Statix check
statix_issues=$(statix check 2>&1 | grep -c "^.*.nix" || echo "0")

# Load metrics from JSON files
if [ -f "$METRICS_DIR/aggregate-coverage.json" ]; then
  aggregate_coverage=$(jq -r '.aggregate_coverage' "$METRICS_DIR/aggregate-coverage.json")
  critical_coverage=$(jq -r '.critical_path_coverage' "$METRICS_DIR/aggregate-coverage.json")
  host_coverage=$(jq -r '.host_coverage' "$METRICS_DIR/aggregate-coverage.json")
  module_coverage=$(jq -r '.module_coverage' "$METRICS_DIR/aggregate-coverage.json")
  test_suites=$(jq -r '.test_suites' "$METRICS_DIR/aggregate-coverage.json")
  snapshot_assertions=$(jq -r '.snapshot_assertions' "$METRICS_DIR/aggregate-coverage.json")
  hosts_tested=$(jq -r '.hosts_tested' "$METRICS_DIR/aggregate-coverage.json")
  hosts_total=$(jq -r '.hosts_total' "$METRICS_DIR/aggregate-coverage.json")
else
  aggregate_coverage="N/A"
  critical_coverage="N/A"
  host_coverage="N/A"
  module_coverage="N/A"
  test_suites="N/A"
  snapshot_assertions="N/A"
  hosts_tested="N/A"
  hosts_total="N/A"
fi

# Evaluation time
if [ -f "$METRICS_DIR/eval-time.json" ]; then
  eval_time=$(jq -r '.eval_time_seconds' "$METRICS_DIR/eval-time.json")
  eval_time_rounded=$(printf "%.1f" "$eval_time")
else
  eval_time_rounded="N/A"
fi

# Determine overall health status
overall_status="✅ PASS"
if [ "$critical_coverage" != "N/A" ] && [ "$critical_coverage" -lt 100 ]; then
  overall_status="⚠️ NEEDS IMPROVEMENT"
fi
if [ "$deadnix_issues" != "0" ] || [ "$statix_issues" != "0" ] || [ "$unused_modules" != "0" ]; then
  overall_status="⚠️ NEEDS IMPROVEMENT"
fi

# Generate dashboard
cat > "$OUTPUT_FILE" <<EOF
# NixOS Configuration Quality Dashboard

Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## 🎯 Overall Health: $overall_status

## Test Coverage

EOF

if [ "$aggregate_coverage" != "N/A" ]; then
  cat >> "$OUTPUT_FILE" <<EOF
- **Aggregate Coverage**: ${aggregate_coverage}%
- **Critical Path Coverage**: ${critical_coverage}% (boot, networking, users, security, systemd)
- **Host Coverage**: ${host_coverage}% ($hosts_tested/$hosts_total hosts tested)
- **Module Coverage**: ${module_coverage}% (estimated)
- **Test Suites**: $test_suites
- **Snapshot Assertions**: $snapshot_assertions

EOF
else
  cat >> "$OUTPUT_FILE" <<EOF
Coverage metrics not yet collected. Run:
\`\`\`bash
./tools/scripts/namaka-coverage-report.sh --report
./tools/scripts/calculate-coverage.sh
\`\`\`

EOF
fi

cat >> "$OUTPUT_FILE" <<EOF
## Code Quality

- **Dead Code (deadnix)**: $deadnix_issues unused bindings
- **Linting Issues (statix)**: $statix_issues issues
- **Unused Modules**: $unused_modules orphaned modules

EOF

# Add critical paths breakdown if available
if [ -f "$METRICS_DIR/coverage-report.md" ]; then
  cat >> "$OUTPUT_FILE" <<EOF
## Critical Paths Details

EOF
  # Extract critical paths section from coverage report
  sed -n '/## Critical Paths Coverage/,/## /p' "$METRICS_DIR/coverage-report.md" | sed '1d;$d' >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" <<EOF
## Performance

- **Evaluation Time**: ${eval_time_rounded}s (target: <10s)

EOF

# Add closure sizes if available
if ls "$METRICS_DIR"/closure-*.json >/dev/null 2>&1; then
  cat >> "$OUTPUT_FILE" <<EOF
**Closure Sizes:**

EOF
  for file in "$METRICS_DIR"/closure-*.json; do
    host=$(jq -r '.host' "$file")
    size=$(jq -r '.closure_size_mb' "$file")
    limit=$(jq -r '.limit_mb' "$file")

    status="✅"
    if (( $(echo "$size > $limit" | bc -l) )); then
      status="❌"
    fi

    cat >> "$OUTPUT_FILE" <<EOF
- $status **$host**: ${size}MB / ${limit}MB limit
EOF
  done
  echo "" >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" <<EOF
## Quality Metrics Trends

To view trends over time, check the \`.quality-metrics/\` directory for historical data.

## How to Improve

### Increase Coverage

1. Add critical path tests: \`tests/coverage/critical-paths.nix\`
2. Test untested hosts in \`tests/hosts-*/\`
3. Add module-specific tests in \`tests/modules-*/\`

### Fix Code Quality Issues

\`\`\`bash
# Fix formatting and dead code
deadnix --edit .
statix fix .
alejandra .

# Find and remove unused modules
./tools/scripts/detect-unused-modules.sh --verbose
\`\`\`

### Optimize Performance

\`\`\`bash
# Profile evaluation
./tools/scripts/profile-evaluation.sh --host desktop

# Check closure sizes
./tools/scripts/check-closure-size.sh --all
\`\`\`

## Continuous Monitoring

This dashboard is automatically updated by CI on every commit.

**Manual update:**
\`\`\`bash
./tools/scripts/generate-quality-dashboard.sh
\`\`\`
EOF

echo "✅ Dashboard generated: $OUTPUT_FILE"
echo ""
echo "View with: cat $OUTPUT_FILE"
exit 0
