#!/usr/bin/env bash
# Fixture test for the ocws board: classification, cache invalidation and the
# freshness of liveness, session and wait state. Runs the ocws on PATH against
# a throwaway jj repository with a local git origin; nothing touches the real
# fleet or the user's cache.
#
# The cache key covers the jj state only. Everything that can change without a
# jj operation (processes, recent sessions, wait markers) must show up on the
# next board even when the cached classification is reused, which is what the
# live/session/wait cases assert.
set -euo pipefail

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# section <board> <header> prints the rows under a board header.
section() {
	printf '%s\n' "$1" | awk -v h="$2" 'substr($0, 1, 2) == "  " && index($0, h) { f = 1; next } f && /^$/ { exit } f'
}

has() { section "$1" "$2" | grep -Fq -- "$3" || fail "$3 missing from '$2'"; }
has_not() { if section "$1" "$2" | grep -Fq -- "$3"; then fail "$3 unexpectedly in '$2'"; fi; }

command -v ocws >/dev/null 2>&1 || fail "ocws not on PATH"
command -v jj >/dev/null 2>&1 || fail "jj not on PATH"
command -v sqlite3 >/dev/null 2>&1 || fail "sqlite3 not on PATH"

work=$(mktemp -d)
trap 'chmod -R u+w "$work" 2>/dev/null; rm -rf "$work"' EXIT
export HOME="$work/home"
export XDG_CACHE_HOME="$work/cache"
export XDG_DATA_HOME="$work/data"
export OCWS_BASE="$work/base"
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$OCWS_BASE"

# A git origin with a main branch, fetched into a colocated jj repository.
git init -q "$work/origin"
(
	cd "$work/origin"
	echo base >file.txt
	git add file.txt
	git -c user.name=t -c user.email=t@t commit -q -m base
	git branch -M main
)

mkdir "$work/repo"
cd "$work/repo"
jj git init --colocate . >/dev/null 2>&1
jj config set --repo user.name "ocws test" >/dev/null 2>&1
jj config set --repo user.email "ocws@example.invalid" >/dev/null 2>&1
git remote add origin "$work/origin"
jj git fetch >/dev/null 2>&1
jj bookmark track main@origin >/dev/null 2>&1
jj workspace add "$OCWS_BASE/nixos-ws-alpha" --name alpha -r main@origin -m "alpha: started" >/dev/null 2>&1
jj workspace add "$OCWS_BASE/nixos-ws-beta" --name beta -r main@origin -m "beta: started" >/dev/null 2>&1

# alpha carries unpushed content; beta stays an empty workspace on main.
(
	cd "$OCWS_BASE/nixos-ws-alpha"
	echo alpha >a.txt
	jj describe -m "alpha: first" >/dev/null 2>&1
)

warm=$(ocws ls --board)
fresh=$(ocws ls --board --refresh)
[ "$warm" = "$fresh" ] || fail "warm board differs from --refresh"
serial=$(OCWS_BOARD_JOBS=1 ocws ls --board --refresh)
[ "$serial" = "$fresh" ] || fail "serial board differs from the parallel board"

has "$fresh" "IN PROGRESS (unpushed)" "alpha: first"
has "$fresh" "RECLAIMABLE" "beta"
counts=$(ocws ls --counts)
[ "$(printf '%s' "$counts" | wc -w)" -eq 8 ] || fail "counts is not 8 integers: $counts"
[ "$counts" = "2 1 0 1 0 0 1 0" ] || fail "unexpected counts: $counts"
[ "$(ocws ls --counts --refresh)" = "$counts" ] || fail "counts differ on --refresh"

# A description change moves the workspace target, so the cache must miss.
(
	cd "$OCWS_BASE/nixos-ws-alpha"
	jj describe -m "alpha: second" >/dev/null 2>&1
)
warm=$(ocws ls --board)
has "$warm" "IN PROGRESS (unpushed)" "alpha: second"
if section "$warm" "IN PROGRESS (unpushed)" | grep -Fq "alpha: first"; then
	fail "stale description survived the cache"
fi

# A remote bookmark makes the same work in-flight.
(
	cd "$OCWS_BASE/nixos-ws-alpha"
	jj bookmark create alpha-work -r @ >/dev/null 2>&1
	jj git push --bookmark alpha-work >/dev/null 2>&1
)
warm=$(ocws ls --board)
has "$warm" "IN REVIEW (open PR)" "alpha"
has_not "$warm" "IN PROGRESS (unpushed)" "alpha"

# Landing the same content on main@origin marks the draft absorbed.
(
	cd "$work/origin"
	echo alpha >a.txt
	git add a.txt
	git -c user.name=t -c user.email=t@t commit -q -m "land alpha"
)
jj git fetch >/dev/null 2>&1
warm=$(ocws ls --board)
has "$warm" "RECLAIMABLE" "alpha"
has_not "$warm" "IN REVIEW (open PR)" "alpha"

# Wait markers are read fresh, never cached.
ocws wait alpha "blocked on review" >/dev/null
warm=$(ocws ls --board)
has "$warm" "PARKED (waiting on the outside world)" "parked: blocked on review"
ocws go alpha >/dev/null
warm=$(ocws ls --board)
has_not "$warm" "PARKED (waiting on the outside world)" "alpha"

# A live process is read fresh, never cached.
(
	cd "$OCWS_BASE/nixos-ws-beta"
	exec sleep 30
) &
sleeper=$!
sleep 0.3
warm=$(ocws ls --board)
has "$warm" "CLAIMED (session active)" "beta"
kill "$sleeper" 2>/dev/null || true
wait "$sleeper" 2>/dev/null || true
warm=$(ocws ls --board)
has "$warm" "RECLAIMABLE" "beta"

# A recent opencode session is read fresh, never cached.
mkdir -p "$XDG_DATA_HOME/opencode"
sqlite3 "$XDG_DATA_HOME/opencode/opencode.db" \
	"create table session_v2 (directory text, time_archived integer, time_updated integer);
	insert into session_v2 values ('$OCWS_BASE/nixos-ws-beta', null, $(($(date +%s) * 1000)));"
warm=$(ocws ls --board)
has "$warm" "CLAIMED (session active)" "beta"
sqlite3 "$XDG_DATA_HOME/opencode/opencode.db" "update session_v2 set time_updated = 0;"
warm=$(ocws ls --board)
has "$warm" "RECLAIMABLE" "beta"

# A workspace add moves the list in the key.
jj workspace add "$OCWS_BASE/nixos-ws-gamma" --name gamma -r main@origin -m "gamma: started" >/dev/null 2>&1
warm=$(ocws ls --board)
has "$warm" "RECLAIMABLE" "gamma"

# A forget removes it again.
jj workspace forget gamma >/dev/null 2>&1
warm=$(ocws ls --board)
has_not "$warm" "RECLAIMABLE" "gamma"

# A corrupt cache is a miss, not a wrong board.
expected=$(ocws ls --board --refresh)
cache=$(find "$XDG_CACHE_HOME/ocws" -name 'board-*' ! -name '*.lock' | head -1)
[ -n "$cache" ] || fail "no board cache was written"
printf 'garbage\n' >"$cache"
[ "$(ocws ls --board)" = "$expected" ] || fail "corrupt cache changed the board"

# An unwritable cache directory is a miss, not a failure or stderr noise. Drop
# the lock too: an existing lock file stays writable through a read-only
# directory and would hide the open failure this guards against.
rm -f "$cache" "$cache.lock"
chmod 500 "$XDG_CACHE_HOME/ocws"
if ! out=$(ocws ls --board 2>"$work/unwritable.err"); then
	fail "unwritable cache failed the board"
fi
[ "$out" = "$expected" ] || fail "unwritable cache changed the board"
[ -s "$work/unwritable.err" ] && fail "unwritable cache wrote to stderr"
chmod 700 "$XDG_CACHE_HOME/ocws"
[ "$(ocws ls --board)" = "$expected" ] || fail "board did not recover after the cache became writable"

# Two concurrent cold scans agree and leave a valid cache behind.
rm -f "$cache"
ocws ls --board --refresh >"$work/a" &
first=$!
ocws ls --board --refresh >"$work/b" &
second=$!
wait "$first"
wait "$second"
cmp -s "$work/a" "$work/b" || fail "concurrent boards differ"
[ "$(ocws ls --board)" = "$(cat "$work/a")" ] || fail "cache after concurrent scans is wrong"

# gc still classifies through the per-workspace path and keeps live work.
(
	cd "$OCWS_BASE/nixos-ws-alpha"
	echo more >>a.txt
	jj describe -m "alpha: more" >/dev/null 2>&1
)
ocws gc 2>&1 | grep -Fq "keeping 'alpha'" || fail "gc did not keep alpha's unpushed work"

# The table rendering is unchanged and still works.
ocws ls | grep -Fq "Workspace states:" || fail "table rendering missing"

printf 'ocws board fixture: ok\n'
