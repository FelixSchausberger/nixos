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

run_detector() { # $1 = state file, $2 = fixture; prints stderr output
	local state=$1 fixture=$2
	{
		env COMIN_STATUS=done COMIN_HOSTNAME=testhost \
			COMIN_GIT_SHA=deadbee \
			COMIN_PROFILE="$tmp/profiles/system" \
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

expect_report \
	$'openssl: 20250101 → 20240101, -5 KiB\n' \
	"openssl: 20250101 → 20240101" \
	"pure-decimal versions still compared as versions"

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
