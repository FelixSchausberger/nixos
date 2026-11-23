#!/usr/bin/env bash
# Consumer contract for the pinned ocws input.
#
# The project's own board test owns the classifier. This check pins only what
# this repository reads from the binary: the eight-field `ls --counts` order,
# the board headings, the wait/go marker round trip, gc's refusal to reclaim
# unpushed work, and the fields `ocws seat --json` returns to the lead/worker
# protocol. Runs against a throwaway jj repository with a local git origin.
set -euo pipefail

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

command -v ocws >/dev/null 2>&1 || fail "ocws not on PATH"
command -v jj >/dev/null 2>&1 || fail "jj not on PATH"
command -v sqlite3 >/dev/null 2>&1 || fail "sqlite3 not on PATH"
command -v jq >/dev/null 2>&1 || fail "jq not on PATH"

work=$(mktemp -d)
trap 'chmod -R u+w "$work" 2>/dev/null; rm -rf "$work"' EXIT
export HOME="$work/home"
export XDG_CACHE_HOME="$work/cache"
export XDG_DATA_HOME="$work/data"
export OCWS_BASE="$work/base"
export OCWS_WS_PREFIX="nixos-ws-"
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$OCWS_BASE"

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
jj config set --repo user.name "ocws contract" >/dev/null 2>&1
jj config set --repo user.email "ocws@example.invalid" >/dev/null 2>&1
git remote add origin "$work/origin"
jj git fetch >/dev/null 2>&1
jj bookmark track main@origin >/dev/null 2>&1

# A fresh repository has only the primary workspace; the badge and digest
# still call counts, so both shapes must work before any seat exists.
[ "$(ocws ls --counts --refresh)" = "0 0 0 0 0 0 0 0" ] || fail "fresh repo counts"
ocws ls --board --refresh | grep -Fq "ocws board -" || fail "fresh repo board"

jj workspace add "$OCWS_BASE/nixos-ws-alpha" --name alpha -r main@origin -m "alpha: started" >/dev/null 2>&1
jj workspace add "$OCWS_BASE/nixos-ws-beta" --name beta -r main@origin -m "beta: started" >/dev/null 2>&1
(
	cd "$OCWS_BASE/nixos-ws-alpha"
	echo alpha >a.txt
	jj describe -m "alpha: first" >/dev/null 2>&1
)

# The eight integers, in order: total empty merged unpushed inflight conflict
# stale waitold. The badge and the digest parse this line positionally.
counts=$(ocws ls --counts --refresh)
[ "$(printf '%s' "$counts" | wc -w)" -eq 8 ] || fail "counts is not 8 integers: $counts"
[ "$counts" = "2 1 0 1 0 0 1 0" ] || fail "unexpected counts: $counts"

# The board headings the popup and the digest render.
board=$(ocws ls --board --refresh)
printf '%s\n' "$board" | grep -Fq "ocws board - state derived from jj" || fail "board header missing"
printf '%s\n' "$board" | grep -Fq "IN PROGRESS (unpushed)" || fail "unpushed heading missing"
printf '%s\n' "$board" | grep -Fq "RECLAIMABLE (gc removes once idle and unoccupied)" || fail "reclaimable heading missing"
printf '%s\n' "$board" | grep -Fq "alpha: first" || fail "alpha missing from the board"

# Park and release: the marker lives beside the workspace and is read fresh.
ocws wait alpha "blocked on review" >/dev/null
[ -f "$OCWS_BASE/alpha.wait" ] || fail "wait marker not written"
ocws ls --board | grep -Fq "PARKED (waiting on the outside world)" || fail "parked heading missing"
ocws go alpha >/dev/null
[ -f "$OCWS_BASE/alpha.wait" ] && fail "wait marker survived go"

# gc keeps unpushed work.
ocws gc 2>&1 | grep -Fq "keeping 'alpha'" || fail "gc did not keep alpha"

# seat --json: the lead/worker protocol reads these fields by name. A fake
# herdr reports the calling session on one pane; the workspace lookup uses the
# fixture's registered alpha workspace.
mkdir -p "$work/bin"
printf '#!%s\nprintf %s\n' "$(command -v bash)" "'{\"result\":{\"agents\":[{\"agent_session\":{\"value\":\"ses_contract\"},\"workspace_id\":\"w1\",\"tab_id\":\"t1\",\"pane_id\":\"p1\",\"agent_status\":\"idle\"}]}}\n'" >"$work/bin/herdr"
chmod +x "$work/bin/herdr"
seat=$(
	cd "$OCWS_BASE/nixos-ws-alpha"
	OPENCODE_SESSION_ID=ses_contract HERDR_BIN_PATH="$work/bin/herdr" ocws seat --json
)
printf '%s' "$seat" | jq -e '
  has("task") and has("dir") and has("herdr_workspace") and has("herdr_tab")
  and has("herdr_pane") and has("agent_session") and has("agent_status") and has("source")
' >/dev/null || fail "seat --json lost a contract field: $seat"
[ "$(printf '%s' "$seat" | jq -r .task)" = "alpha" ] || fail "seat task mismatch"
[ "$(printf '%s' "$seat" | jq -r .herdr_pane)" = "p1" ] || fail "seat pane mismatch"
[ "$(printf '%s' "$seat" | jq -r .agent_session)" = "ses_contract" ] || fail "seat session mismatch"
[ "$(printf '%s' "$seat" | jq -r .source)" = "agent-session" ] || fail "seat source mismatch"

printf 'ocws consumer contract: ok\n'
