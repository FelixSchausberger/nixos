#!/usr/bin/env bash
# Unit tests for classify-daily-update-failure.sh.
set -euo pipefail

classifier="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/classify-daily-update-failure.sh"

fail=0
check() {
	local name="$1" expected="$2" decision="${3:-}" cancelled="${4:-}"
	local actual
	actual="$(DECISION="$decision" CANCELLED_JOBS="$cancelled" "$classifier" <<<"$log")"
	case "$actual" in
	*"$expected"*) printf 'ok - %s\n' "$name" ;;
	*)
		printf 'FAIL - %s\nexpected: %s\nactual:   %s\n' "$name" "$expected" "$actual" >&2
		fail=1
		;;
	esac
}

log="Failed assertions: the option does not exist"
check "eval-failed decision" "config change needed (eval-failed)" "eval-failed"

log=""
check "cancelled job" "cancelled: Build and push desktop" "" $'Build and push desktop'

log="##[error]The hosted runner lost communication with the server. Anything in your workflow that terminates the runner process can cause this error."
check "lost runner" "runner lost" "" ""

log="error: The option definition 'services.foo' in '/nix/store/00000000000000000000000000000000-source/nixos/modules/foo.nix' no longer has any effect"
check "removed option" "option definition 'services.foo'" "" ""

log="error: builder for '/nix/store/00000000000000000000000000000000-foo.drv' failed with exit code 1"
check "build failure" "dependency build failure" "" ""

log="error: hash mismatch in fixed-output derivation '/nix/store/foo.drv'"
check "cache gap" "cache gap" "" ""

log="error: No space left on device"
check "disk full" "disk full" "" ""

log="something unexpected"
check "unclassified" "unclassified" "" ""

if [ "$fail" -ne 0 ]; then
	exit 1
fi
printf 'all classify-daily-update-failure tests passed\n'
