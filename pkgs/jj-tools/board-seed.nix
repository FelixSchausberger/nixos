# One-shot, idempotent seeding of the fleet board's lanes. Board state lives
# in the daemon's sqlite database, which the NixOS configuration does not
# own, so this runs by hand once on the herdr server host instead of from a
# boot or activation unit. Every call names the board by canonical scope path
# (`--board`); `--project` would move the persistent selection, which the
# fleet pin must keep on the repo project. Re-running is safe: an already
# seeded board is reported and left alone, and any other shape is refused
# before the first mutation.
{
  writeShellApplication,
  coreutils,
  gnused,
  jq,
  herdr-board,
}:
writeShellApplication {
  name = "board-seed";
  runtimeInputs = [
    coreutils
    gnused
    jq
    herdr-board
  ];
  text = ''
    set -euo pipefail

    board_dir=/per/etc/nixos
    board_cmd=(board --board "$board_dir")

    fail() {
      echo "board-seed: $*" >&2
      exit 1
    }

    # Same host gate as ocws's card hook: a host-local daemon would seed its
    # own database instead of the fleet board.
    systemctl --user is-enabled herdr-boardd.service >/dev/null 2>&1 \
      || fail "not the herdr server host (the herdr-boardd unit is not enabled here)"

    daemon="$(timeout 5 board version --json 2>/dev/null | jq -r 'if .daemon_version and .daemon_version != "unavailable" then .daemon_version else empty end' 2>/dev/null)"
    [ -n "$daemon" ] || fail "no running board daemon (start it with 'board tui' or the herdr-boardd unit)"

    columns="$(timeout 5 "''${board_cmd[@]}" column list --json 2>/dev/null)" \
      || fail "cannot list columns for $board_dir (is the project pinned there?)"
    cards="$(timeout 5 "''${board_cmd[@]}" card list --json 2>/dev/null)" \
      || fail "cannot list cards for $board_dir"

    want='["To-Do","Backlog","In Progress","In Review","Done","Blocked","Follow Up"]'
    have="$(jq -c '[.[] | .name]' <<<"$columns")"
    card_count="$(jq 'length' <<<"$cards")"

    [ "$card_count" -eq 0 ] \
      || fail "the board already holds $card_count active card(s); refusing to reshape columns under live work"

    if [ "$have" = "$want" ]; then
      echo "board-seed: already seeded: $have"
      exit 0
    fi

    case "$have" in
      '["Todo"]' | '["To-Do"]') ;;
      *) fail "refusing to seed: expected only the seed intake column, found $have" ;;
    esac

    if [ "$have" = '["Todo"]' ]; then
      timeout 5 "''${board_cmd[@]}" column edit Todo --name "To-Do" >/dev/null
    fi

    # Manual lanes carry no prompt: a person decides what enters them. The two
    # automatic lanes dispatch a run on entry; their prompts bind the agent to
    # the card's ocws workspace and to the board's comment/done contract.
    in_progress_prompt='You are in the In Progress lane. Work in the ocws jj workspace at the card space cwd; the jj change description is the claim, so never create a second workspace or claim. Read the workspace jj log and diff for context, follow the repository AGENTS.md (jjwork before edits, one concern per change, run the validation battery), and do not push or deploy unless the card comments or the user ask for it. Report progress with board comment and close the stage with board done.'
    in_review_prompt='You are in the In Review lane. Review the work in the card ocws jj workspace: inspect jj log, the diff against main@origin, the claim description and the card comments. Be adversarial about correctness, failure modes and the repository rules; do not edit the work. Comment the verdict and close with board done --outcome ok when the work is sound, or --outcome fail when it needs rework (the card returns to In Progress).'

    timeout 5 "''${board_cmd[@]}" column create --name Backlog --trigger manual --position 1 >/dev/null
    timeout 5 "''${board_cmd[@]}" column create --name "In Progress" --trigger auto --harness opencode \
      --prompt "$in_progress_prompt" --position 2 >/dev/null
    timeout 5 "''${board_cmd[@]}" column create --name "In Review" --trigger auto --harness opencode --fresh-session \
      --prompt "$in_review_prompt" --position 3 >/dev/null
    timeout 5 "''${board_cmd[@]}" column create --name Done --trigger manual --position 4 >/dev/null
    timeout 5 "''${board_cmd[@]}" column create --name Blocked --trigger manual --position 5 >/dev/null
    timeout 5 "''${board_cmd[@]}" column create --name "Follow Up" --trigger manual --position 6 >/dev/null

    # Wiring after creation: the targets only exist once all lanes are in
    # place, and a failure here leaves a readable, partially seeded board that
    # the precondition above refuses to reshape again.
    timeout 5 "''${board_cmd[@]}" column edit "In Progress" --on-success "In Review" --on-fail Blocked >/dev/null
    timeout 5 "''${board_cmd[@]}" column edit "In Review" --on-success Done --on-fail "In Progress" >/dev/null

    echo "board-seed: seeded: $want"
  '';
}
