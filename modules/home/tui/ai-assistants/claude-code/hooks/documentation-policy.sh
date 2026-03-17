#!/usr/bin/env bash
# Claude Code Documentation Policy Hook
# Enforces documentation policy: only README.md at root and docs/adr/*.md allowed

set -euo pipefail

# Get the target file path from command line arguments
if [ $# -lt 1 ]; then
	echo "Error: Missing file path argument" >&2
	exit 1
fi

target_file="$1"

# Convert to absolute path for consistent comparison
if [[ "$target_file" != /* ]]; then
	# Relative path - resolve against current working directory
	target_file="$(realpath -m "$target_file")"
else
	# Absolute path - normalize it
	target_file="$(realpath -m "$target_file")"
fi

# Get repository root (assuming we're in a git repo)
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

# Convert to relative path from repo root for pattern matching
if [[ "$target_file" == "$repo_root"* ]]; then
	rel_path="${target_file#$repo_root/}"
else
	rel_path="$target_file"
fi

# Policy: Only allow .md files in specific locations
allow_file=false

# Check if it's README.md at repository root
if [[ "$rel_path" == "README.md" ]]; then
	allow_file=true
fi

# Check if it's under docs/adr/
if [[ "$rel_path" == docs/adr/*.md ]]; then
	allow_file=true
fi

# If it's not a .md file, allow it (policy only applies to Markdown)
if [[ "$rel_path" != *.md ]]; then
	allow_file=true
fi

# Enforce the policy
if [ "$allow_file" = false ]; then
	{
		echo "🚫 DOCUMENTATION POLICY VIOLATION"
		echo
		echo "Markdown documentation is restricted by policy."
		echo
		echo "Attempted to create/modify: $rel_path"
		echo
		echo "ALLOWED LOCATIONS:"
		echo "  • README.md (repository root)"
		echo "  • docs/adr/*.md (Architecture Decision Records)"
		echo
		echo "ALTERNATIVES:"
		echo "  • Code documentation → Use code comments"
		echo "  • Long-lived rationale → Create ADR in docs/adr/"
		echo "  • Temporary notes → Use archive/ or move to code"
		echo
		echo "To create an ADR:"
		echo "  1. Use docs/adr/####-title.md format"
		echo "  2. Follow the ADR template in docs/adr/README.md"
		echo "  3. See docs/adr/0001-documentation-policy.md for example"
		echo
	} >&2
	exit 1
fi

# File is allowed by policy
exit 0
