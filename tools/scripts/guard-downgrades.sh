#!/usr/bin/env bash
# Guard against package downgrades when deploying or updating.
#
# Compares the currently active system profile against a freshly built
# toplevel and fails the deployment if any package would be downgraded.
# This prevents the rolling nixpkgs semver channel (or divergent per-host
# lock files) from silently regressing package versions.
#
# Usage:
#   guard-downgrades.sh [NEW_TOPLEVEL]   # default: ./result
#
# Overrides (escapes the guard deliberately):
#   ALLOW_DOWNGRADE=1                    allow every downgrade
#   ALLOW_DOWNGRADES="pkg1 pkg2"         allow downgrades only for these pkgs
#
# Exit codes: 0 = ok, 1 = downgrade(s) found, 2 = usage/error
set -euo pipefail

NEW="${1:-./result}"
OLD="/nix/var/nix/profiles/system"

if [[ ! -e "$NEW" ]]; then
	echo "error: new toplevel not found at $NEW (build with 'nh os build -o ...')" >&2
	exit 2
fi

if [[ ! -e "$OLD" ]]; then
	echo "error: current system profile not found at $OLD" >&2
	exit 2
fi

if [[ "${ALLOW_DOWNGRADE:-}" == "1" ]]; then
	echo "ALLOW_DOWNGRADE=1 set — skipping downgrade guard"
	exit 0
fi

declare -a allowed=()
if [[ -n "${ALLOW_DOWNGRADES:-}" ]]; then
	IFS=' ' read -r -a allowed <<<"$ALLOW_DOWNGRADES"
fi

in_allowed() {
	local pkg="$1"
	for a in "${allowed[@]}"; do
		[[ "$a" == "$pkg" ]] && return 0
	done
	return 1
}

# nix store diff-closures emits lines like:
#   dolphin: 20.08.1 → 20.08.2, +13.9 KiB
# We only care about lines carrying a version arrow (a change, not add/remove).
mapfile -t diff_lines < <(nix store diff-closures "$OLD" "$NEW" 2>/dev/null)

declare -a downgrades=()
while IFS= read -r line; do
	[[ "$line" =~ ^([^:]+):\ ([^ →]+)\ →\ ([^ ,]+) ]] || continue
	pkg="${BASH_REMATCH[1]}"
	old="${BASH_REMATCH[2]}"
	new="${BASH_REMATCH[3]}"

	# versionOlder new old -> true means new is older (a downgrade)
	if [[ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | head -n1)" == "$new" && "$old" != "$new" ]]; then
		if ! in_allowed "$pkg"; then
			downgrades+=("$pkg: $old → $new")
		fi
	fi
done < <(printf '%s\n' "${diff_lines[@]:-}")

if [[ ${#downgrades[@]} -gt 0 ]]; then
	echo "blocked: ${#downgrades[@]} package(s) would be downgraded:"
	for d in "${downgrades[@]}"; do
		echo "  $d"
	done
	echo ""
	echo "To allow all downgrades:  ALLOW_DOWNGRADE=1 guard-downgrades.sh"
	echo "To allow specific pkgs:   ALLOW_DOWNGRADES=\"pkg1 pkg2\" guard-downgrades.sh"
	exit 1
fi

echo "ok: no package downgrades detected"
