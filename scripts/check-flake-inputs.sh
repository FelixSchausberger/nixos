#!/usr/bin/env bash
# Flake Input Count Checker
# Tracks direct and transitive flake inputs to detect dependency sprawl
#
# Exit codes:
#   0 - Input count within limits
#   1 - Threshold exceeded, regression detected, or check failed
#
# Usage:
#   ./check-flake-inputs.sh                 # Check with defaults
#   ./check-flake-inputs.sh --max-direct 55 # Custom direct input threshold
#   ./check-flake-inputs.sh --max-delta 5   # Allow larger baseline growth
#   ./check-flake-inputs.sh --set-baseline  # Store current count as baseline
#
# Run --set-baseline after intentional input additions and commit the result.
# Baseline file: .quality-metrics/flake-inputs-baseline.json

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
MAX_DIRECT=50  # Fail if direct inputs exceed this count
MAX_DELTA=3    # Fail if direct count grew more than this from baseline
OUTPUT_DIR=".quality-metrics"
SET_BASELINE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-direct)
      MAX_DIRECT="$2"
      shift 2
      ;;
    --max-delta)
      MAX_DELTA="$2"
      shift 2
      ;;
    --set-baseline)
      SET_BASELINE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Checks flake input count for dependency sprawl."
      echo ""
      echo "Options:"
      echo "  --max-direct N    Max direct inputs before failing (default: 50)"
      echo "  --max-delta N     Max growth from baseline before failing (default: 3)"
      echo "  --set-baseline    Store current count as new baseline"
      echo "  -h, --help        Show this help message"
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

LOCK_FILE="flake.lock"
if [ ! -f "$LOCK_FILE" ]; then
  echo "flake.lock not found" >&2
  exit 1
fi

# Count direct inputs (root node's immediate dependencies)
direct_count=$(jq '.nodes.root.inputs | length' "$LOCK_FILE")

# Count total lock nodes minus root itself
total_count=$(jq '(.nodes | length) - 1' "$LOCK_FILE")

BASELINE_FILE="$OUTPUT_DIR/flake-inputs-baseline.json"

if [ "$SET_BASELINE" = true ]; then
  jq -n \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --argjson direct "$direct_count" \
    --argjson total "$total_count" \
    '{timestamp: $ts, direct_count: $direct, total_count: $total}' \
    > "$BASELINE_FILE"
  echo "Baseline set: $direct_count direct / $total_count total inputs"
  exit 0
fi

# Compare to baseline if it exists
delta_from_baseline=0
baseline_direct="null"
if [ -f "$BASELINE_FILE" ]; then
  baseline_direct=$(jq -r '.direct_count' "$BASELINE_FILE")
  delta_from_baseline=$((direct_count - baseline_direct))

  if [ "$delta_from_baseline" -gt "$MAX_DELTA" ]; then
    echo "Direct inputs grew by $delta_from_baseline since baseline ($baseline_direct -> $direct_count)" >&2
    echo "Exceeds max delta of $MAX_DELTA. Run --set-baseline after intentional additions." >&2
    exit 1
  fi
fi

# Write output before threshold check so callers can inspect it on failure
jq -n \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --argjson direct "$direct_count" \
  --argjson total "$total_count" \
  --argjson threshold "$MAX_DIRECT" \
  --argjson baseline "$baseline_direct" \
  --argjson delta "$delta_from_baseline" \
  '{
    timestamp: $ts,
    direct_count: $direct,
    total_count: $total,
    threshold: $threshold,
    baseline_direct: $baseline,
    delta_from_baseline: $delta
  }' \
  > "$OUTPUT_DIR/flake-inputs.json"

# Check absolute threshold
if [ "$direct_count" -gt "$MAX_DIRECT" ]; then
  echo "Direct input count ($direct_count) exceeds threshold ($MAX_DIRECT)" >&2
  exit 1
fi

echo "Flake inputs: $direct_count direct / $total_count total (threshold: $MAX_DIRECT direct)"
exit 0
