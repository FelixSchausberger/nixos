#!/usr/bin/env bash
# Abort a local deploy when the working copy is behind origin/main.
#
# A stale working copy builds a stale flake.lock, so the downgrade guard
# would compare the deployed system against an outdated closure and either
# block on a phantom downgrade or, worse, switch to one. Fetching is
# read-only: this script never rebases, never mutates flake.lock, and never
# deploys. Sync explicitly with `jjwork` (or `update` for a lock refresh).
#
# Usage:
#   check-freshness.sh [--no-fetch]
#
# Overrides:
#   DEPLOY_STALE_OK=1    deploy anyway (e.g. intentional offline deploy)
#   DEPLOY_NO_FETCH=1    skip the fetch, compare against last-known origin/main
#
# Exit codes: 0 = fresh or bypassed, 1 = behind, 2 = usage/error
set -euo pipefail

NO_FETCH=0
if [[ "${1:-}" == "--no-fetch" ]]; then
	NO_FETCH=1
elif [[ -n "${1:-}" ]]; then
	echo "error: unknown argument '$1' (only --no-fetch)" >&2
	exit 2
fi
[[ "${DEPLOY_NO_FETCH:-0}" == "1" ]] && NO_FETCH=1

FLAKE="${NH_FLAKE:-/per/etc/nixos}"

if ! git -C "$FLAKE" rev-parse --git-dir >/dev/null 2>&1; then
	echo "error: $FLAKE is not a git checkout; cannot compare with origin/main" >&2
	exit 2
fi

if [[ "${DEPLOY_STALE_OK:-}" == "1" ]]; then
	echo "DEPLOY_STALE_OK=1 set — skipping freshness check"
	exit 0
fi

if [[ "$NO_FETCH" -eq 0 ]]; then
	if ! git -C "$FLAKE" fetch origin main --quiet 2>/dev/null; then
		echo "warn: fetch of origin/main failed (offline?); comparing against last-known origin/main" >&2
		echo "      bypass with DEPLOY_STALE_OK=1 only if you mean to deploy stale" >&2
	fi
fi

if ! git -C "$FLAKE" rev-parse --verify -q origin/main >/dev/null; then
	echo "error: origin/main unknown; fetch once before deploying" >&2
	exit 2
fi

behind=$(git -C "$FLAKE" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
if [[ "$behind" -eq 0 ]]; then
	exit 0
fi

if git -C "$FLAKE" diff --quiet HEAD origin/main -- flake.lock 2>/dev/null; then
	lock_note="flake.lock unchanged"
else
	lock_note="flake.lock changed on origin/main"
fi

cat >&2 <<EOF
stale: origin/main is $behind commit(s) ahead ($lock_note).
Deploying now would build a stale closure that comin is about to replace.
Sync first: jjwork  (or: update, for a fresh lock refresh)
Bypass (not recommended): DEPLOY_STALE_OK=1 deploy
EOF
exit 1
