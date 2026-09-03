#!/usr/bin/env bash
# Trigger an immediate lock refresh through CI and let comin converge.
#
# flake.lock has a single writer: the daily-updates GitHub Actions workflow
# (daily cron). This script dispatches the same workflow on demand, streams
# the run's live job/step progress (gh run watch), waits for the resulting PR
# to auto-merge, syncs the local working copy onto main, and restarts comin so
# the host converges immediately instead of waiting for its next poll.
# Deployment itself is comin's job; the downgrade guard remains in the
# interactive deploy path (nh.nix aliases), while comin reports regressions
# through detect-downgrades.sh after automated deployments.
#
# Exit codes: 0 = merged or gracefully timed out (automation converges later),
# 1 = CI or validation failure
set -euo pipefail

FLAKE="${NH_FLAKE:-/per/etc/nixos}"
WORKFLOW="daily-updates.yml"
BRANCH="daily-updates"
TIMEOUT_SECS="${UPDATE_TIMEOUT_SECS:-1200}"
POLL_INTERVAL=10
MERGE_TIMEOUT_SECS="${UPDATE_MERGE_TIMEOUT_SECS:-600}"
LOG_TAIL_LINES=40

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

timed_out() {
	echo "warn: timed out after ${TIMEOUT_SECS}s; comin converges once CI merges" >&2
	exit 0
}

merge_timed_out() {
	echo "warn: PR '$BRANCH' did not merge within ${MERGE_TIMEOUT_SECS}s; comin converges once it merges" >&2
	exit 0
}

jj --repository "$FLAKE" status

pr_state() { gh_ pr view "$BRANCH" --json state --jq .state 2>/dev/null || true; }

state=$(pr_state)
if [[ "$state" == "OPEN" ]]; then
	echo "update: PR '$BRANCH' already open; waiting for it to merge"
else
	deadline=$(($(date +%s) + TIMEOUT_SECS))
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
		(($(date +%s) < deadline)) || timed_out
	done

	echo "update: streaming run $run_id"
	set +e
	# timeout(1) execs a binary and cannot see the gh_() shell function,
	# so call gh directly here (previously: timeout ... gh_ ... -> exit 127).
	timeout "$TIMEOUT_SECS" gh -R "$REPO" run watch "$run_id" \
		--exit-status --interval "$POLL_INTERVAL"
	watch_rc=$?
	set -e
	case "$watch_rc" in
	0) ;;
	124) timed_out ;;
	*)
		echo "error: CI run failed (exit $watch_rc); lock unchanged, system untouched" >&2
		gh_ run view "$run_id" --log-failed 2>/dev/null | tail -n "$LOG_TAIL_LINES" >&2 || true
		exit 1
		;;
	esac
	state=$(pr_state)
fi

case "$state" in
MERGED) ;;
OPEN)
	echo "update: waiting for auto-merge of the '$BRANCH' PR"
	merge_deadline=$(($(date +%s) + MERGE_TIMEOUT_SECS))
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
		(($(date +%s) < merge_deadline)) || merge_timed_out
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

# Surface what landed so the user sees the effect without opening GitHub.
old_head=$(git -C "$FLAKE" rev-parse HEAD)
echo "update: syncing working copy onto main"
jjwork
new_head=$(git -C "$FLAKE" rev-parse HEAD)
if [[ "$new_head" != "$old_head" ]]; then
	echo "update: changes landed on main:"
	git -C "$FLAKE" show --stat --oneline "$new_head" | head -n 8

	# Input-level diff: resolve each root input through follows chains to its
	# locked node in both lock files, print inputs whose rev/date moved.
	tmpdir=$(mktemp -d /tmp/update-diff.XXXXXX)
	trap 'rm -rf "$tmpdir"' EXIT
	git -C "$FLAKE" show "$old_head:flake.lock" >"$tmpdir/old-lock.json"
	jq -r '
		def target($l; $path):
			reduce $path[] as $seg ("root";
				. as $cur | ($l.nodes[$cur].inputs[$seg] // $cur));
		def info($l; $name):
			($l.nodes[$name].locked // null) as $c
			| if ($c | type) != "object" or ($c.rev // null) == null then "?"
				else "\(($c.lastModified // 0) | strftime("%Y-%m-%d")) \($c.rev[0:7])"
				end;
		. as $new | $old[0] as $o |
		[($o.nodes.root.inputs | keys[])] as $names |
		$names[]
		| . as $name
		| (target($o; [$name]) | info($o; .)) as $before
		| (target($new; [$name]) | info($new; .)) as $after
		| select($before != $after)
		| "  \($name)\t\($before) → \($after)"
	' --slurpfile old "$tmpdir/old-lock.json" <"$FLAKE/flake.lock" >"$tmpdir/inputs.txt" || true

	if [[ -s "$tmpdir/inputs.txt" ]]; then
		echo "update: inputs changed:"
		column -t -s $'\t' "$tmpdir/inputs.txt" 2>/dev/null || cat "$tmpdir/inputs.txt"
	else
		echo "update: no input revisions changed (snapshot-only update)"
	fi

	# Package-level diff: build both closures and let nix store diff-closures
	# produce the nh-style list. Failures here degrade to a warning - the
	# update itself has already succeeded.
	if [[ "${UPDATE_PKG_DIFF:-1}" == "1" ]]; then
		host=$(hostname -s)
		attr="nixosConfigurations.$host.config.system.build.toplevel"
		worktree="$tmpdir/old-tree"
		old_c=""
		new_c=""
		if git -C "$FLAKE" worktree add --detach -q "$worktree" "$old_head" 2>/dev/null; then
			old_c=$(timeout "${UPDATE_BUILD_TIMEOUT:-300}" nix build \
				--no-link --print-out-paths "$worktree#$attr" \
				2>"$tmpdir/old-build.err" | tail -1) || true
			new_c=$(timeout "${UPDATE_BUILD_TIMEOUT:-300}" nix build \
				--no-link --print-out-paths "$FLAKE#$attr" \
				2>"$tmpdir/new-build.err" | tail -1) || true
			git -C "$FLAKE" worktree remove --force "$worktree" 2>/dev/null || true
			git -C "$FLAKE" worktree prune 2>/dev/null || true
		fi
		if [[ -n "$old_c" && -n "$new_c" ]]; then
			if [[ "$old_c" == "$new_c" ]]; then
				echo "update: package closures identical"
			else
				echo "update: package changes:"
				nix store diff-closures "$old_c" "$new_c" || true
			fi
		elif [[ -d "$worktree" ]]; then
			echo "warn: package diff unavailable (build failed); last errors:" >&2
			tail -n 5 "$tmpdir/old-build.err" "$tmpdir/new-build.err" 2>/dev/null | sed 's/^/  /' >&2
		fi
	fi
fi

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
