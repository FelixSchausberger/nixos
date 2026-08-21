#!/usr/bin/env bash
# Trigger an immediate lock refresh through CI and let comin converge.
#
# flake.lock has a single writer: the weekly-updates GitHub Actions workflow
# (daily cron). This script dispatches the same workflow on demand, waits for
# the resulting PR to auto-merge, syncs the local working copy onto main, and
# restarts comin so the host converges immediately instead of waiting for its
# next poll. Deployment itself is comin's job; the downgrade guard remains in
# the interactive deploy path (nh.nix aliases), while comin reports
# regressions through detect-downgrades.sh after automated deployments.
#
# Exit codes: 0 = merged or gracefully timed out (automation converges later),
# 1 = CI or validation failure
set -euo pipefail

FLAKE="${NH_FLAKE:-/per/etc/nixos}"
WORKFLOW="weekly-updates.yml"
BRANCH="weekly-updates"
TIMEOUT_SECS="${UPDATE_TIMEOUT_SECS:-1200}"
POLL_INTERVAL=10
DEADLINE=$(($(date +%s) + TIMEOUT_SECS))

repo_slug() {
	local url
	url=$(git -C "$FLAKE" remote get-url origin 2>/dev/null || true)
	url=${url%.git}
	url=${url#git@github.com:}
	url=${url#https://github.com/}
	printf '%s' "$url"
}

REPO="${UPDATE_REPO:-$(repo_slug)}"
if [[ -z "$REPO" ]]; then
	echo "error: cannot determine GitHub repository from $FLAKE remotes" >&2
	exit 1
fi

gh_() { gh -R "$REPO" "$@"; }

remaining() { echo $((DEADLINE - $(date +%s))); }

timed_out() {
	echo "warn: timed out after ${TIMEOUT_SECS}s; comin converges once CI merges" >&2
	exit 0
}

jj --repository "$FLAKE" status

pr_state() { gh_ pr view "$BRANCH" --json state --jq .state 2>/dev/null || true; }

state=$(pr_state)
if [[ "$state" == "OPEN" ]]; then
	echo "update: PR '$BRANCH' already open; waiting for it to merge"
else
	before=$(gh_ run list --workflow="$WORKFLOW" -L 1 --json databaseId \
		--jq 'first(.[]).databaseId' 2>/dev/null || echo 0)
	gh_ workflow run "$WORKFLOW"
	echo "update: workflow dispatched on $REPO; waiting for the run to start"

	run_id=""
	while :; do
		sleep "$POLL_INTERVAL"
		run_id=$(gh_ run list --workflow="$WORKFLOW" -L 1 --json databaseId \
			--jq 'first(.[]).databaseId' 2>/dev/null || echo "")
		if [[ -n "$run_id" && "$run_id" != "$before" ]]; then
			break
		fi
		(($(date +%s) < DEADLINE)) || timed_out
	done

	echo "update: watching run $run_id"
	while :; do
		sleep "$POLL_INTERVAL"
		status=$(gh_ run view "$run_id" --json status,conclusion \
			--jq '.status + "/" + (.conclusion // "pending")' 2>/dev/null || echo unknown)
		case "$status" in
		completed/success)
			break
			;;
		completed/*)
			echo "error: CI run failed ($status); lock unchanged, system untouched" >&2
			exit 1
			;;
		esac
		echo "  run status: $status ($(remaining)s left)"
		(($(date +%s) < DEADLINE)) || timed_out
	done
	state=$(pr_state)
fi

case "$state" in
MERGED) ;;
OPEN)
	echo "update: waiting for auto-merge of the '$BRANCH' PR"
	while :; do
		sleep "$POLL_INTERVAL"
		state=$(pr_state)
		if [[ "$state" == "MERGED" ]]; then
			break
		fi
		if [[ "$state" != "OPEN" ]]; then
			echo "error: PR left open state without merging (state=$state)" >&2
			exit 1
		fi
		(($(date +%s) < DEADLINE)) || timed_out
	done
	;;
"")
	echo "update: CI produced no changes; lock is already fresh"
	;;
*)
	echo "error: unexpected PR state '$state'" >&2
	exit 1
	;;
esac

echo "update: syncing working copy onto main"
jjwork

if systemctl is-active --quiet comin; then
	if sudo systemctl restart comin; then
		echo "update: comin restarted; deploying now instead of next poll"
	else
		echo "warn: could not restart comin; it converges within its poll period" >&2
	fi
else
	echo "update: comin is not active on this host; nothing to converge"
fi
echo "update: done"
