#!/usr/bin/env bash
# Block raw git operations that bypass jj's commit graph.
# Triggered as PreToolUse for Bash. Input: JSON on stdin.
# Exit 2 to block the command; exit 0 to allow.
#
# Escape hatch: include "# jj-bypass" anywhere in the command to skip all checks.

set -euo pipefail

COMMAND=$(cat | jq -r '.tool_input.command // ""')

# Allow explicit override
if printf '%s' "$COMMAND" | grep -qF '# jj-bypass'; then
    exit 0
fi

# Operations that rewrite history or push outside jj — all silently drop jj-only commits
declare -a BLOCKED=(
    "git reset"
    "git push --force"
    "git push -f"
    "git rebase"
    "git commit"
    "git stash"
)

for PATTERN in "${BLOCKED[@]}"; do
    if printf '%s' "$COMMAND" | grep -qF "$PATTERN"; then
        cat >&2 <<'EOF'
Raw git operation blocked — this repo is managed by jj.

jj equivalents:
  git reset --soft N      ->  jj squash --from "children(BASE)::@" --into BASE
  git push --force        ->  jj git push  (force is automatic after history rewrite)
  git commit              ->  jj describe -m "..." && jj new
  git stash               ->  jj new  (working copy is always a commit in jj)
  git checkout HEAD -- .  ->  jj restore
  git checkout <rev> -- . ->  jj restore --from <rev>

Read-only git commands (log, show, diff, grep, ls-remote) are fine.
To bypass intentionally: append  # jj-bypass  to the command.
EOF
        exit 2
    fi
done

# git checkout <treeish> -- <path> silently overwrites the working tree —
# identical in destructiveness to git reset --hard.
# The pathspec separator " -- " distinguishes this from a safe branch switch.
if printf '%s' "$COMMAND" | grep -qE 'git checkout .+ -- '; then
    cat >&2 <<'EOF'
Raw git operation blocked — this repo is managed by jj.

jj equivalents:
  git reset --soft N      ->  jj squash --from "children(BASE)::@" --into BASE
  git push --force        ->  jj git push  (force is automatic after history rewrite)
  git commit              ->  jj describe -m "..." && jj new
  git stash               ->  jj new  (working copy is always a commit in jj)
  git checkout HEAD -- .  ->  jj restore
  git checkout <rev> -- . ->  jj restore --from <rev>

Read-only git commands (log, show, diff, grep, ls-remote) are fine.
To bypass intentionally: append  # jj-bypass  to the command.
EOF
    exit 2
fi

exit 0
