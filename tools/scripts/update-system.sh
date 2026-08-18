#!/usr/bin/env bash
# Smart system update: deploy the committed config when it is at least as new
# as the deployed system, otherwise refresh all flake inputs and deploy.
#
# Never bulk-downgrades: the downgrade guard is mandatory in every deploy path
# and ALLOW_DOWNGRADE=1 (bulk bypass) is refused. Intentional per-package
# downgrades are handled through ALLOW_DOWNGRADES (passes through to the guard)
# or by pinning the offending input in flake.nix.
#
# Exit codes: 0 = deployed, 1 = blocked/failed, 2 = guard usage error
set -euo pipefail

FLAKE="${NH_FLAKE:-/per/etc/nixos}"
GUARD="$FLAKE/tools/scripts/guard-downgrades.sh"
RESULT="/tmp/nh-result"

if [[ "${ALLOW_DOWNGRADE:-}" == "1" ]]; then
	echo "error: ALLOW_DOWNGRADE=1 is refused in the update flow (no bulk downgrades)" >&2
	echo "  for a per-package downgrade use: ALLOW_DOWNGRADES=\"pkg1 pkg2\"" >&2
	exit 1
fi

# Non-blocking sanity check: shows untracked files and pending changes
jj --repository "$FLAKE" status

deploy() {
	# nh os switch <path> skips flake evaluation and deploys the guarded closure.
	# The store path is resolved first because root cannot follow the
	# /tmp/nh-result symlink across ZFS datasets with posix ACLs.
	nh os switch -d never "$(readlink -f "$RESULT")"
	validate-system
}

# Phase 1: deploy the committed config as-is (no input refresh). A committed
# build that fails to evaluate is a config error, not an update concern.
if ! nh os build -S -o "$RESULT"; then
	echo "error: committed config failed to build; fix it before updating" >&2
	exit 1
fi

set +e
"$GUARD" "$RESULT"
guard_rc=$?
set -e

if [[ $guard_rc -eq 0 ]]; then
	echo "update: committed config is at least as new as deployed; deploying"
	deploy
	exit 0
fi
if [[ $guard_rc -eq 2 ]]; then
	exit 2
fi

# committed config is older than deployed; refresh all inputs and retry
echo "update: committed config is older than deployed; updating all flake inputs"
nh os build --update -S -o "$RESULT"

set +e
"$GUARD" "$RESULT"
guard_rc=$?
set -e

if [[ $guard_rc -ne 0 ]]; then
	echo "update: blocked — even after refreshing inputs, packages would be downgraded" >&2
	echo "  handle per-package: ALLOW_DOWNGRADES=\"pkg1 pkg2\" or pin the input in flake.nix" >&2
	exit 1
fi

echo "update: inputs refreshed and no downgrades; deploying"
deploy
