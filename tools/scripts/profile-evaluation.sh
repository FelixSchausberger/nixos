#!/usr/bin/env bash
# Evaluation Performance Profiler
# Profiles Nix evaluation time to identify slow modules and bottlenecks
#
# Exit codes:
#   0 - Evaluation within performance threshold
#   1 - Evaluation exceeds threshold or profiling failed
#
# Usage:
#   ./profile-evaluation.sh                  # Profile desktop config
#   ./profile-evaluation.sh --host portable  # Profile specific host
#   ./profile-evaluation.sh --threshold 15   # Custom threshold (seconds)

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
HOST="desktop"
THRESHOLD=10  # Default: 10 seconds max evaluation time
OUTPUT_DIR=".quality-metrics"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Profiles Nix evaluation performance."
      echo ""
      echo "Options:"
      echo "  --host NAME      Host configuration to profile (default: desktop)"
      echo "  --threshold N    Max evaluation time in seconds (default: 10)"
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
mkdir -p "$OUTPUT_DIR"

echo "🔍 Profiling evaluation performance for: $HOST"
echo ""

# Measure evaluation time
echo "Evaluating configuration..."
start_time=$(date +%s.%N)

# Use nix eval with stats to get detailed timing
if NIX_SHOW_STATS=1 nix eval --no-update-lock-file \
  ".#nixosConfigurations.$HOST.config.system.build.toplevel" \
  --apply 'x: x.name' 2>&1 | tee "$OUTPUT_DIR/eval-stats.log"; then

  end_time=$(date +%s.%N)
  eval_time=$(echo "$end_time - $start_time" | bc)

  echo ""
  echo "✅ Evaluation completed in ${eval_time}s"

  # Extract key statistics from NIX_SHOW_STATS output
  if grep -q "time elapsed" "$OUTPUT_DIR/eval-stats.log"; then
    echo ""
    echo "📊 Evaluation Statistics:"
    grep "time elapsed\|nr-attr-lookups\|nr-primop-calls" "$OUTPUT_DIR/eval-stats.log" || true
  fi

  # Save metrics to JSON
  cat > "$OUTPUT_DIR/eval-time.json" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "host": "$HOST",
  "eval_time_seconds": $eval_time,
  "threshold_seconds": $THRESHOLD
}
EOF

  echo ""
  echo "📊 Metrics written to: $OUTPUT_DIR/eval-time.json"

  # Check threshold
  if (( $(echo "$eval_time > $THRESHOLD" | bc -l) )); then
    echo ""
    echo "❌ Evaluation time (${eval_time}s) exceeds threshold (${THRESHOLD}s)"
    echo ""
    echo "Consider:"
    echo "  • Check for heavy imports (nixpkgs imported multiple times)"
    echo "  • Review module complexity in modules/system and modules/home"
    echo "  • Profile individual modules with: nix eval .#nixosConfigurations.$HOST.config.<module>"
    exit 1
  fi

  echo "✅ Evaluation time within threshold (${eval_time}s <= ${THRESHOLD}s)"
  exit 0
else
  echo ""
  echo "❌ Evaluation failed"
  exit 1
fi
