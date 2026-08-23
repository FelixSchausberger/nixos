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
		# Find matching lines with line numbers
		while IFS=: read -r line_num content; do
			[ -z "$line_num" ] && continue

			# Skip if this line has an inline suppression
			if echo "$content" | grep -q "nocheck: dangerous-shell-patterns"; then
				continue
			fi

			# Skip if the preceding line has a suppression comment
			if [ "$line_num" -gt 1 ]; then
				prev_line=$(sed -n "$((line_num - 1))p" "$file")
				if echo "$prev_line" | grep -q "nocheck: dangerous-shell-patterns"; then
					continue
				fi
			fi

			echo "${line_num}:${content}"
			echo "Dangerous pattern found in $file:"
			echo "   Pattern: '$pattern'"
			echo "   Using 'exec' with terminal multiplexers causes shell lockouts!"
			echo "   Use official integration method instead:"
			echo "      eval (zellij setup --generate-auto-start fish | string collect)"
			echo "   To suppress a false positive, put on the line before:"
			echo "      # nocheck: dangerous-shell-patterns"
			echo ""
			found_issues=true
		done < <(grep -n "$pattern" "$file" 2>/dev/null || true)
	done
done

if [ "$found_issues" = true ]; then
	echo "Dangerous patterns detected. Fix the issues above before committing."
	exit 1
fi

echo "No dangerous patterns found"
exit 0
