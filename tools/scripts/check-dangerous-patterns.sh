#!/usr/bin/env bash
# Dangerous Shell Pattern Detector
# Prevents deployment of configurations with known dangerous patterns
#
# Suppression: add  # nocheck: dangerous-shell-patterns  to suppress a specific line.
#
# Exit codes:
#   0 - No dangerous patterns found
#   1 - Dangerous patterns detected

set -euo pipefail

# Dangerous patterns that can cause shell lockouts
DANGEROUS_PATTERNS=(
	"exec zellij"
	"exec tmux"
	"exec screen"
	"exec wezterm"
)

found_issues=false

# If no files provided, exit successfully
if [ $# -eq 0 ]; then
	exit 0
fi

echo "Checking for dangerous shell patterns..."

for file in "$@"; do
	# Skip if file doesn't exist
	[ -f "$file" ] || continue

	for pattern in "${DANGEROUS_PATTERNS[@]}"; do
		# grep -n for matching lines, then exclude suppressed lines
		matches=$(grep -n "$pattern" "$file" 2>/dev/null |
			grep -v "nocheck: dangerous-shell-patterns" || true)

		if [ -n "$matches" ]; then
			echo "$matches"
			echo "Dangerous pattern found in $file:"
			echo "   Pattern: '$pattern'"
			echo "   Using 'exec' with terminal multiplexers causes shell lockouts!"
			echo "   Use official integration method instead:"
			echo "      eval (zellij setup --generate-auto-start fish | string collect)"
			echo "   To suppress a false positive, append to the line:"
			echo "      # nocheck: dangerous-shell-patterns"
			echo ""
			found_issues=true
		fi
	done
done

if [ "$found_issues" = true ]; then
	echo "Dangerous patterns detected. Fix the issues above before committing."
	exit 1
fi

echo "No dangerous patterns found"
exit 0
