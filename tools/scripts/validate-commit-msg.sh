#!/usr/bin/env bash
# Validates commit messages follow conventional commit format
# Format: type(scope?): description
# See: https://www.conventionalcommits.org/

set -euo pipefail

# Get commit message
commit_msg_file="${1:-}"
if [[ -z "$commit_msg_file" ]] || [[ ! -f "$commit_msg_file" ]]; then
  echo "ERROR: Commit message file not provided or not found"
  exit 1
fi

commit_msg=$(cat "$commit_msg_file")

# Skip merge commits and revert commits
if echo "$commit_msg" | head -1 | grep -qE '^(Merge|Revert)'; then
  exit 0
fi

# Conventional commits pattern
# type(scope?): description
# Types: feat, fix, docs, style, refactor, perf, test, chore
pattern="^(feat|fix|docs|style|refactor|perf|test|chore)(\(.+\))?: .{1,72}"

# Validate first line
first_line=$(echo "$commit_msg" | head -1)

if ! echo "$first_line" | grep -qE "$pattern"; then
  echo ""
  echo "❌ ERROR: Commit message doesn't follow conventional commits format"
  echo ""
  echo "Current message:"
  echo "  $first_line"
  echo ""
  echo "Expected format:"
  echo "  type(scope?): description"
  echo ""
  echo "Valid types:"
  echo "  feat     - A new feature"
  echo "  fix      - A bug fix"
  echo "  docs     - Documentation only changes"
  echo "  style    - Code style changes (formatting, etc.)"
  echo "  refactor - Code change that neither fixes a bug nor adds a feature"
  echo "  perf     - Performance improvement"
  echo "  test     - Adding or updating tests"
  echo "  chore    - Maintenance tasks, dependency updates, etc."
  echo ""
  echo "Examples:"
  echo "  feat: add auto-merge workflow"
  echo "  fix: resolve jj bookmark creation issue"
  echo "  docs: update jujutsu workflow guide"
  echo "  feat(ci): optimize cachix push filter"
  echo ""
  exit 1
fi

# Success
exit 0
