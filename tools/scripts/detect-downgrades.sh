#!/usr/bin/env bash
# Report package downgrades introduced by an automated comin deployment.
#
# Runs as root from the comin service after each deployment. Comin provides
# context through COMIN_* environment variables; only successful deployments
# create a generation worth diffing. Downgrades are reported to ntfy when
# COMIN_NTFY_URL is set, otherwise logged to the journal.
#
# The automated deployment path cannot block, so this is detection rather
# than prevention: a bad lock is healed by reverting its commit on main,
# after which every host converges back within one poll period.
#
# Identical downgrades alert once, not once per deploy: seen pairs are
# recorded in a persisted state file and only unseen pairs are reported.
#
# Exit codes: 0 = nothing to report or alert sent, 1 = unexpected state
set -euo pipefail

# Shared downgrade predicate (single implementation with guard-downgrades.sh).
# SC1091: dynamic sibling path (same dir in repo, store, and unit-test
# bundles); the lib file is linted directly, so no coverage is lost.
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-downgrade-compare.sh"

# Failed deployments leave the previous generation active; nothing changed.
if [[ "${COMIN_STATUS:-}" != "done" ]]; then
	exit 0
fi

# COMIN_PROFILE overrides the profile to read; production always uses
# comin's own profile. It exists so the diffing logic can be unit-tested
# against fixture generation links.
#
# comin's profile, not the NixOS system profile, is the deployment record:
# every successful switch adds one numbered link beside it and points the
# profile at it, while test deployments add none. The NixOS `system` profile
# only tracks comin where persistSwitch mirrors it, so hosts that leave that
# off keep pointing at their last nixos-rebuild generation and would compare
# two stale generations instead of this deployment.
profile="${COMIN_PROFILE:-/nix/var/nix/profiles/system-profiles/comin}"

# COMIN_DOWNGRADES_STATE overrides where seen downgrades are recorded;
# production always uses comin's persisted state directory.
seen_file="${COMIN_DOWNGRADES_STATE:-/var/lib/comin/detected-downgrades}"

# Parse `<prefix>-<n>-link` and walk down to the highest existing link below
# it: comin numbers its generations without gaps only for successes, and a
# pruned link must not silently disable the detector.
target=$(readlink "$profile")
name=$(basename -- "$target")
if [[ ! "$name" =~ ^(.+)-([0-9]+)-link$ ]]; then
	exit 0
fi
prefix="${BASH_REMATCH[1]}-"
cur_num=$((10#${BASH_REMATCH[2]}))
prev=""
for ((num = cur_num - 1; num > 0; num--)); do
	candidate="$(dirname "$profile")/${prefix}${num}-link"
	if [[ -e "$candidate" ]]; then
		prev="$candidate"
		break
	fi
done
if [[ -z "$prev" ]]; then
	exit 0
fi

old=$(readlink -f "$prev")
new=$(readlink -f "$profile")

# nix store diff-closures emits lines like:
#   dolphin: 20.08.1 → 20.08.2, +13.9 KiB
# Only lines carrying a version arrow are changes, not add/remove.
# The diff is captured into a variable and fed via here-string: process
# substitution would require /dev/fd, which is unavailable under some
# sandboxing profiles (and the detector then silently sees nothing).
diff_output=$(nix store diff-closures "$old" "$new" 2>/dev/null) || true

downgrades=""
while IFS= read -r line; do
	[[ "$line" =~ ^([^:]+):\ (.+)\ →\ ([^ ,]+) ]] || continue
	pkg="${BASH_REMATCH[1]}"
	old_v="${BASH_REMATCH[2]}"
	new_v="${BASH_REMATCH[3]}"
	if is_downgrade "$old_v" "$new_v"; then
		downgrades+="$pkg: $old_v → $new_v"$'\n'
	fi
done <<<"$diff_output"

# Repeat suppression: comin deploys every poll period while a bad lock sits
# on main, so an unchanged downgrade would alert once per deploy. The file
# tracks the current set: only unseen pairs alert, healing empties the set,
# and a later re-appearance of the same pair alerts again.
if [[ -z "$downgrades" ]]; then
	if [[ -e "$seen_file" ]]; then
		rm -f "$seen_file"
	fi
	exit 0
fi

new_downgrades=""
while IFS= read -r line; do
	[[ -z "$line" ]] && continue
	if [[ ! -e "$seen_file" ]] || ! grep -qxF -- "$line" "$seen_file"; then
		new_downgrades+="$line"$'\n'
	fi
done <<<"$downgrades"

# Every pair already reported and still present: stay quiet.
if [[ -z "$new_downgrades" ]]; then
	exit 0
fi

mkdir -p "$(dirname "$seen_file")"
printf '%s' "$downgrades" >"$seen_file"

host="${COMIN_HOSTNAME:-$(cat /etc/hostname 2>/dev/null || echo unknown)}"
message="comin deployed downgraded packages on ${host} (${COMIN_GIT_SHA:-unknown sha}):
${downgrades}
Heal by reverting the lock commit on main."

if [[ -n "${COMIN_NTFY_URL:-}" ]]; then
	curl -fsS \
		-H "Title: Package downgrade detected on ${host}" \
		-H "Priority: high" \
		-H "Tags: warning" \
		-d "$message" \
		"$COMIN_NTFY_URL" >/dev/null
else
	echo "$message" >&2
fi
