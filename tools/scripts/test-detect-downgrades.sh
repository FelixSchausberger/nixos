#!/usr/bin/env bash
# Unit test for detect-downgrades.sh.
#
# Runs the detector against fixture generation links with a stubbed
# `nix store diff-closures`. Verifies that only version-to-version
# regressions are reported: package additions ("∅ → v"), removals
# ("v → ε"), and upgrades must stay silent. Also verifies repeat
# suppression against a shared state file: an unchanged downgrade alerts
# once, healing clears the memory, and a re-appearance alerts again.
#
# Exit codes: 0 = all scenarios passed, 1 = assertion failed
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
under_test="$script_dir/detect-downgrades.sh"

tmp=$(mktemp -d)

trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/profiles" "$tmp/state"

# Stub nix so `nix store diff-closures` prints the fixture under test.
# The shebang pins the invoking bash because /usr/bin/env does not exist
# inside Nix build sandboxes.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/nix" <<STUB
#!$(command -v bash)
printf '%s' "\$DIFF_CLOSURES_OUTPUT"
STUB
chmod +x "$tmp/bin/nix"

failures=0

ok() { echo "ok   $1"; }
fail() {
	echo "FAIL $1" >&2
	failures=$((failures + 1))
}

reset_profiles() {
	rm -f "$tmp/profiles/system" "$tmp/profiles/system-49-link" "$tmp/profiles/system-50-link"
	mkdir -p "$tmp/store/g49" "$tmp/store/g50"
	ln -sfn "$tmp/store/g50" "$tmp/profiles/system-50-link"
	ln -sfn "$tmp/store/g49" "$tmp/profiles/system-49-link"
	ln -sfn "system-50-link" "$tmp/profiles/system"
}

# comin names its generations `comin-<n>-link` and skips numbers for
# deployments that never became a generation (failed or test operations), so
# the predecessor is not necessarily `n - 1`.
reset_comin_profiles() { # $1 = "gap" | "only"
	rm -f "$tmp/profiles/comin" "$tmp/profiles/comin-"*-link
	mkdir -p "$tmp/store/c503" "$tmp/store/c505"
	ln -sfn "$tmp/store/c505" "$tmp/profiles/comin-505-link"
	if [[ "${1:-gap}" == "gap" ]]; then
		ln -sfn "$tmp/store/c503" "$tmp/profiles/comin-503-link"
	fi
	ln -sfn "comin-505-link" "$tmp/profiles/comin"
}

run_detector() { # $1 = state file, $2 = fixture, [$3 = profile]; prints stderr output
	local state=$1 fixture=$2 profile=${3:-$tmp/profiles/system}
	{
		env COMIN_STATUS=done COMIN_HOSTNAME=testhost \
			COMIN_GIT_SHA=deadbee \
			COMIN_PROFILE="$profile" \
			COMIN_DOWNGRADES_STATE="$state" \
			DIFF_CLOSURES_OUTPUT="$fixture" \
			PATH="$tmp/bin:$PATH" \
			bash "$under_test" >/dev/null
	} 2>&1
}

# Base scenarios run with a throwaway state file each so they are
# independent of one another and of the suppression scenarios below.
fresh_state() { printf '%s' "$tmp/state/base-$RANDOM$RANDOM"; }

expect_report() { # $1 = fixture, $2 = expected stderr substring, $3 = label
	local fixture=$1 expected=$2 label=$3
	reset_profiles
	local err
	err=$(run_detector "$(fresh_state)" "$fixture") || {
		fail "$label: script exited non-zero"
		return 0
	}
	if [[ "$err" != *"$expected"* ]]; then
		echo "FAIL $label: output missing '$expected'; got:" >&2
		echo "$err" >&2
		failures=$((failures + 1))
	elif [[ "$err" != *"comin deployed downgraded packages on testhost"* ]]; then
		fail "$label: report lacks hostname header"
	else
		ok "$label"
	fi
}

expect_silent() { # $1 = fixture, $2 = label
	local fixture=$1 label=$2
	reset_profiles
	local err
	err=$(run_detector "$(fresh_state)" "$fixture") || true
	if [[ -n "$err" ]]; then
		echo "FAIL $label: expected silence, got:" >&2
		echo "$err" >&2
		failures=$((failures + 1))
	else
		ok "$label"
	fi
}

DOWN_OPENSSL=$'openssl: 3.5.1 → 3.5.0, -100.2 KiB\n'
DOWN_MIXED=$'openssl: 3.5.1 → 3.5.0, -100.2 KiB\ncurl: 8.10.0 → 8.11.0, +50.0 KiB\nlibutempter: ∅ → 1.2.3, +45.3 KiB\nmosh: ∅ → 1.4.0, +1.2 MiB\nwrapper: ∅ → ε\noldpkg: 2.1 → ε, -10 KiB\n'

expect_report \
	"$DOWN_MIXED" \
	"openssl: 3.5.1 → 3.5.0" \
	"real downgrade reported, additions/removals/upgrades filtered"

expect_silent \
	$'libutempter: ∅ → 1.2.3, +45.3 KiB\nmosh: ∅ → 1.4.0, +1.2 MiB\n' \
	"additions-only deployment stays silent"

expect_silent "" "empty diff stays silent"

expect_silent \
	$'iris: 42416fc → 387bb7f, +1.2 MiB\n' \
	"git short rev bump stays silent"

expect_silent \
	$'pkg: 1.2.3 → 0abcdef, +10 KiB\n' \
	"version-to-rev change stays silent"

expect_silent \
	$'tree-sitter-fish: 0.0.0+rev=f435b0b → 0.0.0+rev=b7f1d68, -110.4 KiB\n' \
	"rev-suffixed ref bump stays silent"

expect_report \
	$'pkg: 1.2.3+rev=abcdef1 → 1.2.2+rev=0abcdef, -10 KiB\n' \
	"pkg: 1.2.3+rev=abcdef1 → 1.2.2+rev=0abcdef" \
	"rev-suffixed base regression still reported"

expect_report \
	$'openssl: 20250101 → 20240101, -5 KiB\n' \
	"openssl: 20250101 → 20240101" \
	"pure-decimal versions still compared as versions"

# A closure can carry several builds of one name (Nextcloud's plain and
# -with-apps outputs); diff-closures lists them comma-separated and the
# regression must still be reported, not dropped by the line parser.
expect_report \
	$'nextcloud: 35.0.3, 35.0.3-with → 35.0.2, 35.0.2-with, -2.8 MiB\n' \
	"nextcloud: 35.0.3, 35.0.3-with → 35.0.2" \
	"multi-version closure regression reported"

expect_silent \
	$'pkg: 1.2, 1.3 → 1.2, 1.3, +0 B\n' \
	"unchanged multi-version closure stays silent"

# Production reads comin's own profile, whose links carry a `comin-` prefix
# and skip numbers that never became a generation. Falling back to the
# highest existing link keeps the detector working when the predecessor
# number is absent; the first deployment has no predecessor and stays silent.
reset_comin_profiles gap
err=$(run_detector "$(fresh_state)" "$DOWN_OPENSSL" "$tmp/profiles/comin") || true
if [[ "$err" == *"openssl: 3.5.1 → 3.5.0"* ]]; then
	ok "comin profile reports despite a missing predecessor number"
else
	fail "comin profile reports despite a missing predecessor number (got: $err)"
fi

reset_comin_profiles only
err=$(run_detector "$(fresh_state)" "$DOWN_OPENSSL" "$tmp/profiles/comin") || true
if [[ -z "$err" ]]; then
	ok "first comin deployment stays silent"
else
	fail "first comin deployment stays silent (got: $err)"
fi

# Repeat suppression against one shared state file, mirroring production:
# comin deploys repeatedly while the bad lock sits on main.
seen="$tmp/state/seen"
rm -f "$seen"

# First sighting is reported and recorded.
reset_profiles
err=$(run_detector "$seen" "$DOWN_OPENSSL") || true
if [[ "$err" == *"openssl: 3.5.1 → 3.5.0"* && -s "$seen" ]]; then
	ok "first sighting reported and recorded"
else
	fail "first sighting reported and recorded (got: $err)"
fi

# Identical repeat on the next deploy stays silent but keeps the record.
reset_profiles
err=$(run_detector "$seen" "$DOWN_OPENSSL") || true
if [[ -z "$err" && -s "$seen" ]]; then
	ok "identical repeat stays silent"
else
	fail "identical repeat stays silent (got: $err)"
fi

# A new downgrade alongside a known one is reported.
reset_profiles
err=$(run_detector "$seen" $'openssl: 3.5.1 → 3.5.0, -100.2 KiB\nzlib: 1.3.1 → 1.3, -10 KiB\n') || true
if [[ "$err" == *"zlib: 1.3.1 → 1.3"* ]]; then
	ok "new pair alongside known ones reported"
else
	fail "new pair alongside known ones reported (got: $err)"
fi

# Healed deployment (no downgrades) clears the record silently.
reset_profiles
err=$(run_detector "$seen" "") || true
if [[ -z "$err" && ! -e "$seen" ]]; then
	ok "healed deployment clears the record"
else
	fail "healed deployment clears the record (file present: $([[ -e "$seen" ]] && echo yes || echo no))"
fi

# Re-appearance after healing alerts again instead of staying suppressed.
reset_profiles
err=$(run_detector "$seen" "$DOWN_OPENSSL") || true
if [[ "$err" == *"openssl: 3.5.1 → 3.5.0"* ]]; then
	ok "re-appearance after healing alerts again"
else
	fail "re-appearance after healing alerts again (got: $err)"
fi

if [[ $failures -gt 0 ]]; then
	echo "$failures scenario(s) failed" >&2
	exit 1
fi
