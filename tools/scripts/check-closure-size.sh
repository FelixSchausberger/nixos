#!/usr/bin/env bash
# Closure Size Checker
# Calculates system closure size and detects size regressions
#
# Exit codes:
#   0 - Closure size within limits
#   1 - Closure size exceeds limits or check failed
#
# Usage:
#   ./check-closure-size.sh desktop           # Check desktop closure
#   ./check-closure-size.sh --all             # Check all hosts
#   ./check-closure-size.sh --delta 15        # Allow 15% increase

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
MAX_DELTA_PERCENT=10  # Default: fail if closure grows >10%
OUTPUT_DIR=".quality-metrics"
CHECK_ALL=false
HOST=""

# Size limits per host (in MB)
declare -A SIZE_LIMITS
SIZE_LIMITS[desktop]=3000    # 3GB
SIZE_LIMITS[portable]=2500   # 2.5GB
SIZE_LIMITS[surface]=2500    # 2.5GB
SIZE_LIMITS[hp-probook-vmware]=2000  # 2GB
SIZE_LIMITS[hp-probook-wsl]=2000     # 2GB

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      CHECK_ALL=true
      shift
      ;;
    --delta)
      MAX_DELTA_PERCENT="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [HOST|--all] [OPTIONS]"
      echo ""
      echo "Checks system closure sizes and detects regressions."
      echo ""
      echo "Arguments:"
      echo "  HOST             Host to check (desktop, portable, surface, etc.)"
      echo "  --all            Check all hosts"
      echo ""
      echo "Options:"
      echo "  --delta N        Max allowed size increase percentage (default: 10)"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
    *)
      HOST="$1"
      shift
      ;;
  esac
done

cd "$REPO_ROOT"
mkdir -p "$OUTPUT_DIR"

# Function to check closure size for a host
check_closure() {
  local host="$1"
  local limit="${SIZE_LIMITS[$host]:-3000}"

  echo "🔍 Checking closure size for: $host"

  # Build the system toplevel
  if ! nix build --no-update-lock-file ".#nixosConfigurations.$host.config.system.build.toplevel" \
    -o "/tmp/closure-$host" 2>&1 | grep -v "copying path"; then
    echo "❌ Failed to build $host configuration" >&2
    return 1
  fi

  # Get closure size
  closure_size=$(nix path-info -S "/tmp/closure-$host" 2>/dev/null | awk '{print $2}' | numfmt --from=iec --to-unit=M)

  echo "  Closure size: ${closure_size}MB (limit: ${limit}MB)"

  # Save current size
  echo "$closure_size" > "$OUTPUT_DIR/closure-$host-current.txt"

  # Check against baseline if it exists
  baseline_file="$OUTPUT_DIR/closure-$host-baseline.txt"
  if [ -f "$baseline_file" ]; then
    baseline=$(cat "$baseline_file")
    delta=$(echo "scale=2; (($closure_size - $baseline) / $baseline) * 100" | bc)

    # Handle negative deltas (size decreased)
    if (( $(echo "$delta < 0" | bc -l) )); then
      echo "  ✅ Size decreased by ${delta#-}% from baseline (${baseline}MB → ${closure_size}MB)"
    elif (( $(echo "$delta > $MAX_DELTA_PERCENT" | bc -l) )); then
      echo "  ❌ Size increased by ${delta}% from baseline (${baseline}MB → ${closure_size}MB)"
      echo "  Exceeds maximum delta of ${MAX_DELTA_PERCENT}%"
      return 1
    else
      echo "  ✅ Size change: ${delta}% from baseline (within ${MAX_DELTA_PERCENT}% limit)"
    fi
  else
    echo "  ℹ️  No baseline found, creating baseline: ${closure_size}MB"
    echo "$closure_size" > "$baseline_file"
  fi

  # Check against absolute limit
  if (( $(echo "$closure_size > $limit" | bc -l) )); then
    echo "  ❌ Closure size (${closure_size}MB) exceeds limit (${limit}MB)"
    return 1
  fi

  # Save metrics
  cat > "$OUTPUT_DIR/closure-$host.json" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "host": "$host",
  "closure_size_mb": $closure_size,
  "limit_mb": $limit,
  "baseline_mb": ${baseline:-null}
}
EOF

  echo "  ✅ Closure size OK"
  echo ""
  return 0
}

# Main execution
failed_hosts=()

if [ "$CHECK_ALL" = true ]; then
  echo "Checking all hosts..."
  echo ""

  for host in "${!SIZE_LIMITS[@]}"; do
    if ! check_closure "$host"; then
      failed_hosts+=("$host")
    fi
  done
elif [ -n "$HOST" ]; then
  if ! check_closure "$HOST"; then
    failed_hosts+=("$HOST")
  fi
else
  echo "Error: Specify a host or use --all" >&2
  echo "Usage: $0 [HOST|--all] [OPTIONS]" >&2
  exit 1
fi

# Summary
if [ ${#failed_hosts[@]} -gt 0 ]; then
  echo "❌ Closure size check failed for: ${failed_hosts[*]}"
  exit 1
fi

echo "✅ All closure size checks passed"
exit 0
