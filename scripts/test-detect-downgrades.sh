#!/usr/bin/env bash
# Unit test for detect-downgrades.sh.
#
# Runs the detector against fixture generation links with a stubbed
# `nix store diff-closures`. Verifies that only version-to-version
# regressions are reported: package additions ("∅ → v"), removals
# ("v → ε"), and upgrades must stay silent.
#
# Exit codes: 0 = all scenarios passed, 1 = assertion failed
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
under_test="$script_dir/detect-downgrades.sh"

tmp=$(mktemp -d)

trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/profiles"

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

expect_report() { # $1 = fixture, $2 = expected stderr substring, $3 = label
	local fixture=$1 expected=$2 label=$3
	mkdir -p "$tmp/store/g49" "$tmp/store/g50"
	ln -sfn "$tmp/store/g50" "$tmp/profiles/system-50-link"
	ln -sfn "$tmp/store/g49" "$tmp/profiles/system-49-link"
	ln -sfn "system-50-link" "$tmp/profiles/system"

	local err
	err=$(env COMIN_STATUS=done COMIN_HOSTNAME=testhost \
		COMIN_GIT_SHA=deadbee \
		COMIN_PROFILE="$tmp/profiles/system" \
		DIFF_CLOSURES_OUTPUT="$fixture" \
		PATH="$tmp/bin:$PATH" \
		bash "$under_test" 2>&1 >/dev/null) || {
		echo "FAIL $label: script exited non-zero" >&2
		failures=$((failures + 1))
		return 0
	}
	if [[ "$err" != *"$expected"* ]]; then
		echo "FAIL $label: output missing '$expected'; got:" >&2
		echo "$err" >&2
		failures=$((failures + 1))
	elif [[ "$err" != *"comin deployed downgraded packages on testhost"* ]]; then
		echo "FAIL $label: report lacks hostname header" >&2
		failures=$((failures + 1))
	else
		echo "ok   $label"
	fi
}

expect_silent() { # $1 = fixture, $2 = label
	local fixture=$1 label=$2
	rm -f "$tmp/profiles/system" "$tmp/profiles/system-49-link" "$tmp/profiles/system-50-link"
	mkdir -p "$tmp/store/g49" "$tmp/store/g50"
	ln -sfn "$tmp/store/g50" "$tmp/profiles/system-50-link"
	ln -sfn "$tmp/store/g49" "$tmp/profiles/system-49-link"
	ln -sfn "system-50-link" "$tmp/profiles/system"

	local err
	err=$(env COMIN_STATUS=done COMIN_HOSTNAME=testhost \
		COMIN_PROFILE="$tmp/profiles/system" \
		DIFF_CLOSURES_OUTPUT="$fixture" \
		PATH="$tmp/bin:$PATH" \
		bash "$under_test" 2>&1 >/dev/null) || true
	if [[ -n "$err" ]]; then
		echo "FAIL $label: expected silence, got:" >&2
		echo "$err" >&2
		failures=$((failures + 1))
	else
		echo "ok   $label"
	fi
}

expect_report \
	$'openssl: 3.5.1 → 3.5.0, -100.2 KiB\ncurl: 8.10.0 → 8.11.0, +50.0 KiB\nlibutempter: ∅ → 1.2.3, +45.3 KiB\nmosh: ∅ → 1.4.0, +1.2 MiB\nwrapper: ∅ → ε\noldpkg: 2.1 → ε, -10 KiB\n' \
	"openssl: 3.5.1 → 3.5.0" \
	"real downgrade reported, additions/removals/upgrades filtered"

expect_silent \
	$'libutempter: ∅ → 1.2.3, +45.3 KiB\nmosh: ∅ → 1.4.0, +1.2 MiB\n' \
	"additions-only deployment stays silent"

expect_silent "" "empty diff stays silent"

if [[ $failures -gt 0 ]]; then
	echo "$failures scenario(s) failed" >&2
	exit 1
fi
