#!/usr/bin/env bash
# Boot Time Profiler
# Captures systemd-analyze boot metrics to detect services that slow startup
#
# Exit codes:
#   0 - Boot time within threshold
#   1 - Threshold exceeded, systemd unavailable, or profiling failed
#
# IMPORTANT: Requires a running systemd instance. Do not run in CI.
#            GitHub Actions runners do not have systemd and this will fail immediately.
#
# Usage:
#   ./profile-boot.sh                    # Profile with defaults
#   ./profile-boot.sh --threshold 20     # Custom userspace threshold (seconds)
#   ./profile-boot.sh --top 15           # Show top 15 services in blame list
#   ./profile-boot.sh --host portable    # Label output with a specific host name

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
THRESHOLD=15  # Default: 15s userspace time (NixOS-controlled portion)
TOP_N=10      # Default: show top 10 services in blame list
HOST="$(hostname)"
OUTPUT_DIR=".quality-metrics"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    --top)
      TOP_N="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Profiles boot time from a running systemd instance."
      echo "Do not run in CI -- requires systemd."
      echo ""
      echo "Options:"
      echo "  --threshold N    Max userspace boot time in seconds (default: 15)"
      echo "  --top N          Services to include in blame list (default: 10)"
      echo "  --host NAME      Host label for output (default: hostname)"
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

if ! command -v systemd-analyze >/dev/null 2>&1; then
  echo "systemd-analyze not available -- run this on a live system, not in CI" >&2
  exit 1
fi

# Total boot time
# Output format: "Startup finished in Xs (firmware) + Xs (loader) + Xs (kernel) + Xs (userspace) = Xs"
# or without firmware/loader on some configurations
raw_analyze=$(systemd-analyze 2>/dev/null)

# Extract userspace time (float with optional decimal)
userspace_s=$(echo "$raw_analyze" | grep -oP '[0-9]+(?:\.[0-9]+)?(?=s \(userspace\))' || true)
# Extract total time (last value after '=')
total_s=$(echo "$raw_analyze" | grep -oP '(?<== )[0-9]+(?:\.[0-9]+)?(?=s\s*$)' || true)

if [ -z "$userspace_s" ] || [ -z "$total_s" ]; then
  echo "Could not parse systemd-analyze output:" >&2
  echo "$raw_analyze" >&2
  exit 1
fi

# Graphical target time from critical-chain
graphical_s=$(systemd-analyze critical-chain graphical.target 2>/dev/null \
  | head -1 \
  | grep -oP '[0-9]+(?:\.[0-9]+)?(?=s\s*$)' || echo "null")

# Top N services from blame list
# Format: "  1.234s unit-name.service"
blame_json=$(systemd-analyze blame 2>/dev/null \
  | head -n "$TOP_N" \
  | awk '{
      # Remove trailing 's' from time value and strip leading whitespace
      gsub(/s$/, "", $1)
      printf "{\"service\": \"%s\", \"time_s\": %s}\n", $2, $1
    }' \
  | jq -s '.')

# Write output
jq -n \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg host "$HOST" \
  --argjson userspace "$userspace_s" \
  --argjson total "$total_s" \
  --argjson threshold "$THRESHOLD" \
  --argjson graphical "${graphical_s:-null}" \
  --argjson services "$blame_json" \
  '{
    timestamp: $ts,
    host: $host,
    userspace_seconds: $userspace,
    total_seconds: $total,
    threshold_userspace_seconds: $threshold,
    graphical_target_seconds: $graphical,
    top_services: $services
  }' \
  > "$OUTPUT_DIR/boot-time.json"

echo "Boot time: ${userspace_s}s userspace / ${total_s}s total (threshold: ${THRESHOLD}s userspace)"
echo "Metrics written to: $OUTPUT_DIR/boot-time.json"

# Check threshold
if (( $(echo "$userspace_s > $THRESHOLD" | bc -l) )); then
  echo "" >&2
  echo "Userspace boot time (${userspace_s}s) exceeds threshold (${THRESHOLD}s)" >&2
  echo "" >&2
  echo "Top services by activation time:" >&2
  systemd-analyze blame 2>/dev/null | head -n 5 >&2
  exit 1
fi

exit 0
