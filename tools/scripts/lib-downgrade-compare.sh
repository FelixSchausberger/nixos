# shellcheck shell=bash
# Shared version-downgrade predicate for guard-downgrades.sh (interactive
# deploy path, blocks) and detect-downgrades.sh (comin post-deploy path,
# reports). Single implementation so both paths classify identically.
#
# Usage: is_downgrade OLD_VERSION NEW_VERSION  (exit 0 = genuine regression)
#
# Rules, in order:
#   git-ref suffixes      -> stripped before comparing ("0.0.0+rev=<ref>":
#                            nixpkgs tree-sitter grammars; the ref is opaque
#                            while the numeric base still regresses normally)
#   equal versions            -> not a downgrade
#   non-version sentinels     -> never a downgrade (diff-closures marks package
#                                additions as "∅ → v" and removals as "v → ε";
#                                sort -V ranks those symbols below any number,
#                                which would otherwise report every removal as
#                                a downgrade)
#   git short revs            -> never a downgrade (opaque identifiers: version
#                                sort ranks them lexically, flagging forward
#                                lock bumps as downgrades; requiring an [a-f]
#                                letter keeps pure-decimal versions such as
#                                dates and build ids on the normal path).
#                                This subsumes the old per-package iris exemption.
#   otherwise                 -> sort -V comparison (newest sorts last)

is_downgrade() {
	local old_v=$1 new_v=$2
	# sort -V ranks ref suffixes lexically (b7f1d68 < f435b0b), which would
	# flag an ordinary grammar bump as a regression; compare the numeric
	# base instead so 1.2.3+rev=x -> 1.2.2+rev=y still reports.
	old_v="${old_v%%+rev=*}"
	new_v="${new_v%%+rev=*}"
	[[ "$new_v" == "$old_v" ]] && return 1
	[[ "$old_v" =~ ^[0-9] && "$new_v" =~ ^[0-9] ]] || return 1
	if [[ "$old_v" =~ ^[0-9a-f]{7,40}$ && "$old_v" =~ [a-f] ]] ||
		[[ "$new_v" =~ ^[0-9a-f]{7,40}$ && "$new_v" =~ [a-f] ]]; then
		return 1
	fi
	[[ "$(printf '%s\n%s\n' "$old_v" "$new_v" | sort -V | head -n1)" == "$new_v" ]]
}
