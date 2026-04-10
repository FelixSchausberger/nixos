#!/usr/bin/env bash
# Unused Module Detector
# Analyzes import graph to find modules that are never imported or used
#
# Exit codes:
#   0 - No unused modules found
#   1 - Unused modules detected or analysis failed
#
# Usage:
#   ./detect-unused-modules.sh                # Analyze all modules
#   ./detect-unused-modules.sh --verbose      # Show detailed analysis

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
MODULES_DIRS=("modules/system" "modules/home")
VERBOSE=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --verbose|-v)
      VERBOSE=true
      ;;
    --help|-h)
      echo "Usage: $0 [--verbose]"
      echo ""
      echo "Detects unused Nix modules in the repository."
      echo ""
      echo "Options:"
      echo "  -v, --verbose    Show detailed analysis"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
  esac
done

cd "$REPO_ROOT"

# Find all .nix files in modules directories
declare -a all_modules=()
for dir in "${MODULES_DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "Warning: Directory $dir does not exist" >&2
    continue
  fi

  while IFS= read -r -d '' file; do
    all_modules+=("$file")
  done < <(find "$dir" -type f -name '*.nix' -print0)
done

if [ ${#all_modules[@]} -eq 0 ]; then
  echo "No modules found in ${MODULES_DIRS[*]}" >&2
  exit 1
fi

if [ "$VERBOSE" = true ]; then
  echo "Found ${#all_modules[@]} module files to analyze"
  echo ""
fi

# Check each module for references
unused_modules=()
for module in "${all_modules[@]}"; do
  # Skip default.nix files (they're typically index files)
  if [[ "$(basename "$module")" == "default.nix" ]]; then
    continue
  fi

  # Get the module path relative to repo root
  module_rel="${module#./}"

  # Search for imports of this module
  # Look for both full path and relative imports
  module_name="$(basename "$module" .nix)"
  module_dir="$(dirname "$module_rel")"

  # Patterns to search for:
  # 1. Full path: ./modules/system/foo.nix or ../modules/system/foo.nix
  # 2. Relative path: ./foo.nix or ../foo.nix (within same directory)
  # 3. Interpolated path: ./${foo}.nix

  # Search in all Nix files except the module itself
  found=false

  # Search for full path references
  if git grep -q "$module_rel" -- '*.nix' >/dev/null 2>&1; then
    found=true
  # Search for just the filename (in case of relative imports)
  elif git grep -q "/${module_name}.nix" -- '*.nix' >/dev/null 2>&1; then
    found=true
  # Special case: modules/*/default.nix files are typically imported by parent
  elif [[ "$(basename "$module")" == "default.nix" ]]; then
    parent_dir="$(basename "$(dirname "$module_rel")")"
    if git grep -q "$parent_dir" -- '*.nix' >/dev/null 2>&1; then
      found=true
    fi
  fi

  if [ "$found" = false ]; then
    unused_modules+=("$module_rel")
    if [ "$VERBOSE" = true ]; then
      echo "❌ Unused: $module_rel"
    fi
  elif [ "$VERBOSE" = true ]; then
    echo "✅ Used: $module_rel"
  fi
done

# Report results
if [ ${#unused_modules[@]} -gt 0 ]; then
  echo "❌ Found ${#unused_modules[@]} unused module(s):"
  echo ""
  for module in "${unused_modules[@]}"; do
    echo "  • $module"
  done
  echo ""
  echo "These modules are defined but never imported."
  echo "Consider removing them or adding them to the appropriate configuration."
  exit 1
fi

echo "✅ No unused modules detected (analyzed ${#all_modules[@]} modules)"
exit 0
