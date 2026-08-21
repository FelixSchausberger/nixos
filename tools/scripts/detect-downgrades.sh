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
# Exit codes: 0 = nothing to report or alert sent, 1 = unexpected state
set -euo pipefail

# Failed deployments leave the previous generation active; nothing changed.
if [[ "${COMIN_STATUS:-}" != "done" ]]; then
	exit 0
fi

profile=/nix/var/nix/profiles/system

# The just-activated generation is the highest numbered link; the one before
# it is what was running until this deployment.
target=$(readlink "$profile")
cur_num=${target//[^0-9]/}
if [[ -z "$cur_num" || "$cur_num" -le 1 ]]; then
	exit 0
fi
prev="/nix/var/nix/profiles/system-$((cur_num - 1))-link"
if [[ ! -e "$prev" ]]; then
	exit 0
fi

old=$(readlink -f "$prev")
new=$(readlink -f "$profile")

# nix store diff-closures emits lines like:
#   dolphin: 20.08.1 → 20.08.2, +13.9 KiB
# Only lines carrying a version arrow are changes, not add/remove.
downgrades=""
while IFS= read -r line; do
	[[ "$line" =~ ^([^:]+):\ ([^ →]+)\ →\ ([^ ,]+) ]] || continue
	old_v="${BASH_REMATCH[2]}"
	new_v="${BASH_REMATCH[3]}"
	# versionOlder new old -> true means new is older (a downgrade)
	if [[ "$new_v" != "$old_v" && "$(printf '%s\n%s\n' "$old_v" "$new_v" | sort -V | head -n1)" == "$new_v" ]]; then
		downgrades+="${line%%,*}"$'\n'
	fi
done < <(nix store diff-closures "$old" "$new" 2>/dev/null)

if [[ -z "$downgrades" ]]; then
	exit 0
fi

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
