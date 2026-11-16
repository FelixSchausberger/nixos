# ocws - opencode workspace. Creates a jj workspace for a single agent,
# claims it with a change description, and starts opencode rooted there, then
# reclaims finished workspaces. jj workspaces are the shared-repo equivalent
# of git worktrees and are the supported way to run parallel agents against
# one repository.
#
# `ocws ls` classifies every workspace (empty, merged, unpushed, in-flight,
# conflict) from the same absorption test that drives reclamation, so stale
# workspaces are visible without mutating anything. `ocws gc` reclaims the
# empty and merged ones; a systemd user timer runs it daily (see the
# jujutsu home module).
#
# A workspace can be parked: `ocws wait <task> [reason...]` marks it waiting
# through an <task>.wait marker beside the workspace directory, and gc keeps
# it whatever its commit state, because a session waiting on the outside
# world (an upstream fix, a device) is not reclaimable regardless of what jj
# sees. Waits older than OCWS_WAIT_STALE_DAYS resurface as gc nudges and a
# prompt-badge reminder, so forgotten waiting is treated like any other
# unclean state rather than a permanent free pass.
#
# Liveness ignores per-project MCP and LSP daemons: they inherit the cwd of
# the session that spawned them and outlive it, so a cwd-only occupancy check
# holds workspaces hostage after the session closed (2026-11 audit: five
# empty workspaces whose only occupants were leaked mcp-nixos processes).
# A cwd-only check misses a session whose TUI already exited, so gc also
# consults the opencode session database: an unarchived session rooted in the
# workspace and updated within OCWS_GC_SESSION_AGE keeps the workspace with no
# process at all. Recency, not a pending prompt, is the observable state -
# unanswered permission asks live in the server's memory and vanish with the
# client - so this is a grace window; 'ocws wait' remains the indefinite
# marker. The probe is guard-silent: no database, no sqlite3, or an unreadable
# schema falls back to the process and touch checks.
# Base directory precedence: $OCWS_BASE, then the parent directory of the
# current workspace (the sibling convention) when writable, then
# $XDG_DATA_HOME/ocws (default ~/.local/share/ocws) so workspaces survive
# reboots without ever needing root, then /tmp/opencode. The workspace
# directory is "<base>/nixos-ws-<task>".
#
# OCWS_V2=1 runs the opencode2 entry point instead of opencode. Both names
# resolve to the same launcher.
#
# OCWS_HOOK_{PRE,POST}_{CREATE,DELETE} run a shell command around workspace
# creation and removal for per-workspace setup/teardown (dev ports, .env
# files, caches). OCWS_TASK/DIR/ROOT/BASE are exported to the hook.
{
  writeShellApplication,
  jujutsu,
  coreutils,
  gnugrep,
  gnused,
  findutils,
  rip2,
  zellij,
  jq,
  sqlite,
  bash,
}:
writeShellApplication {
  name = "ocws";
  runtimeInputs = [
    jujutsu
    coreutils
    gnugrep
    gnused
    findutils
    rip2
    zellij
    jq
    sqlite
    bash
  ];
  text = ''
    set -euo pipefail

    usage() {
      cat >&2 <<'USAGE'
    Usage:
      ocws <task> [-- <opencode args>...]   create a workspace and run opencode there
      ocws tab <task> [-- <opencode args>]  create a workspace in a new zellij tab
      ocws herdr [<task>] [-- <opencode args>]
                                            start an agent seat: create the workspace
                                            and run opencode in a new herdr tab; an
                                            unnamed seat gets a filler task that
                                            'ocws title' replaces
      ocws title <text...>                  claim the current seat: set the change
                                            description, rename the workspace and the
                                            herdr tab from the session title; a no-op
                                            unless the description is still the filler
      ocws ls [--counts|--board]            list workspaces with their state and claim
                                            (--counts prints the integers "total empty merged
                                            unpushed in-flight conflict stale waitold", where
                                            waitold counts parked workspaces older than
                                            OCWS_WAIT_STALE_DAYS; --board groups the same
                                            classification into "what needs you" sections)
      ocws wait <task> [reason...]          park a workspace: gc keeps it until 'ocws go'
                                            clears the marker, whatever its commit state -
                                            for a session waiting on an external blocker
                                            (an upstream fix, a device) that must not hold
                                            its pane open
      ocws go <task>                        release a parked workspace (removes its wait
                                            marker); the next gc pass reclassifies it
      ocws done [--force] <task>            remove a finished workspace (refuses unmerged work
                                            or a live process; --force overrides both)
      ocws rm [--force] <task>              remove a workspace; --force discards unmerged work
      ocws gc                               remove reclaimable workspaces idle past the age gate

    Environment:
      OCWS_BASE     directory holding workspace directories (default: beside the repo
                    when writable, else ~/.local/share/ocws, else /tmp/opencode)
      OCWS_V2=1     run the opencode2 entry point instead of opencode
      OCWS_GC_AGE   seconds a workspace that had work must sit idle before gc
                    removes it (default 86400)
      OCWS_GC_EMPTY_AGE
                    seconds an empty, unclaimed workspace must sit idle before
                    gc removes it (default 21600)
      OCWS_GC_SESSION_AGE
                    seconds an opencode session rooted in a workspace keeps that
                    workspace out of gc, measured from the session's last update
                    (default 604800)
      OCWS_WAIT_STALE_DAYS
                    days after which a parked workspace resurfaces as a gc
                    nudge and in the prompt badge (default 14)
      OCWS_LIVE_EXCLUDE
                    grep -E pattern additionally excluded from the liveness
                    scan, for detecting future auxiliary processes (per-project
                    MCP or LSP daemons) that inherit their parent's cwd
      OCWS_HOOK_PRE_CREATE / OCWS_HOOK_POST_CREATE / OCWS_HOOK_PRE_DELETE /
      OCWS_HOOK_POST_DELETE
                    optional shell commands run around workspace create/remove,
                    with OCWS_TASK/DIR/ROOT/BASE exported
    USAGE
      exit 2
    }

    root="$(jj workspace root 2>/dev/null)" || {
      echo "ocws: not inside a jj workspace" >&2
      exit 1
    }

    base="''${OCWS_BASE:-}"
    if [ -z "$base" ]; then
      candidate="$(dirname "$root")"
      if [ -w "$candidate" ]; then
        base="$candidate"
      else
        base="''${XDG_DATA_HOME:-$HOME/.local/share}/ocws"
        mkdir -p "$base"
      fi
    fi
    if [ ! -w "$base" ]; then
      base=/tmp/opencode
    fi
    mkdir -p "$base"

    valid_task() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; }
    ws_dir_for() { printf '%s/nixos-ws-%s' "$base" "$1"; }
    # Wait markers live beside the workspace directories, never inside them: a
    # marker under the working copy would be snapshotted into the next claim
    # commit by any session that happens to run there. Keyed by task name, and
    # rip_workspace removes it with the workspace so clearing cannot be
    # forgotten by any of the removal paths (done, rm, gc).
    wait_marker_for() { printf '%s/%s.wait' "$base" "$1"; }
    # OCWS_WAIT_STALE_DAYS must survive invalid input without killing the
    # script under errexit: arithmetic on a non-integer aborts a gc pass.
    # The digit check is grep-based, not a shell case on an empty pattern:
    # contiguous quote pairs inside this derivation body terminate the nix
    # indented string, so the shell must never carry two adjacent quotes here.
    wait_stale_days() {
      v="''${OCWS_WAIT_STALE_DAYS:-14}"
      if printf '%s' "$v" | grep -Eq '^[0-9]+$'; then
        printf '%s' "$v"
      else
        echo 14
      fi
    }
    # Workspace listings and the finished-work check are read-only and must
    # never snapshot a foreign working copy: an `ocws ls` run from the primary
    # or another session's workspace would otherwise fold that workspace's
    # uncommitted changes into its @.
    workspace_exists() {
      local names
      names="$(jj --ignore-working-copy workspace list -T 'name ++ "\n"' 2>/dev/null)"
      grep -qx "$1" <<<"$names"
    }
    # Resolve a workspace directory from jj's recorded root (jj >= 0.38 prints
    # an absolute path), falling back to the base-directory convention for
    # pre-0.38 workspaces whose root is not recorded.
    ws_root_for() {
      local out
      out="$(jj --ignore-working-copy workspace list -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null | sed -n "s/^$1\t//p")"
      if [ -n "$out" ] && [ "$out" != "none" ]; then
        printf '%s' "$out"
      else
        ws_dir_for "$1"
      fi
    }
    # A revision is absorbed when every file it touches already has its content
    # on main@origin: a squash-merge replaces the draft commit but lands the
    # same bytes, so the draft is finished even though it is not an ancestor.
    # The touched files are batched into a single diff against main@origin
    # (empty exactly when every file matches) rather than one diff per file.
    # Pure jj, so it also works in a secondary workspace, which has no .git.
    ws_commit_absorbed() {
      local cid="$1"
      local -a files=()
      mapfile -t files < <(jj --ignore-working-copy diff -r "$cid" --name-only 2>/dev/null)
      [ "''${#files[@]}" -eq 0 ] && return 0
      [ -z "$(jj --ignore-working-copy diff --from 'main@origin' --to "$cid" -- "''${files[@]}" 2>/dev/null)" ]
    }
    # Classify a workspace from the commits reachable from its @ that carry
    # content outside main@origin. Prints "<state>\t<@ description>" where
    # state is one of:
    #   empty     - nothing outside main@origin carries content
    #   merged    - off-main content exists but is fully absorbed into main@origin
    #   unpushed  - off-main content not absorbed, no remote bookmark
    #   in-flight - off-main content not absorbed, a remote bookmark (open PR)
    #   conflict  - @ or an off-main commit carries a conflict
    # Absorption per revision is what lets a squash-merged PR count as finished:
    # it leaves the draft off main@origin, so ancestry alone would call it
    # unmerged. Only snapshotted commits are visible; a foreign workspace is
    # never snapshotted (that would fold a live session's edits into its @), so
    # unsnapshotted edits are invisible and rip's graveyard is the recovery net.
    ws_state() {
      local name="$1" rev="$1@" offmain cid rflag desc state has_work=0 has_remote=0
      desc="$(jj --ignore-working-copy log --no-graph -r "$rev" -T 'description.first_line()' 2>/dev/null)"
      offmain="$(jj --ignore-working-copy log --no-graph -r "ancestors($rev) ~ ::main@origin ~ empty()" \
        -T 'commit_id ++ " " ++ if(self.remote_bookmarks(), "R", "-") ++ "\n"' 2>/dev/null)"
      while read -r cid rflag; do
        [ -n "$cid" ] || continue
        [ "$rflag" = "R" ] && has_remote=1
        ws_commit_absorbed "$cid" || has_work=1
      done <<<"$offmain"

      if [ -n "$(jj --ignore-working-copy log --no-graph -r "$rev | (ancestors($rev) ~ ::main@origin)" -T 'if(self.conflict(), "C", "")' 2>/dev/null)" ]; then
        state=conflict
      elif [ -z "$offmain" ]; then
        state=empty
      elif [ "$has_work" = 0 ]; then
        state=merged
      elif [ "$has_remote" = 1 ]; then
        state=in-flight
      else
        state=unpushed
      fi
      printf '%s\t%s\n' "$state" "$desc"
    }
    # A workspace "has work" when its state holds content not yet on
    # main@origin. done/rm refuse to reclaim such a workspace.
    ws_has_work() {
      case "$(ws_state "$1" | cut -f1)" in
        unpushed | in-flight | conflict) return 0 ;;
        *) return 1 ;;
      esac
    }
    # A live session-or-agent process whose cwd is inside the workspace means
    # a session still uses it, even when its work has already merged, so gc
    # must not reclaim under it. Auxiliary daemons (per-project MCP and LSP
    # servers) inherit their spawning session's cwd and outlive it, so the
    # cwd-only check excludes them: live_exclude is the default preset for
    # shipped aux binaries, and OCWS_LIVE_EXCLUDE adds patterns later without
    # a code change. A process whose cmdline cannot be read counts as live -
    # an unreadability distinction cannot be made here, and ocws never kills.
    live_exclude='(^|/)[^ ]*(mcp-[a-z0-9._-]+-wrapped|nix-language-server)[^ ]*'
    [ -n "''${OCWS_LIVE_EXCLUDE:-}" ] && live_exclude="$live_exclude|''${OCWS_LIVE_EXCLUDE}"
    ws_live() {
      local target="$1" p cwd cmd
      for p in /proc/[0-9]*; do
        [ -r "$p/cwd" ] || continue
        cwd="$(readlink "$p/cwd" 2>/dev/null)" || continue
        case "$cwd" in
          "$target" | "$target"/*)
            cmd="$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)" || cmd=""
            printf '%s' "$cmd" | grep -Eq "$live_exclude" && continue
            return 0
            ;;
        esac
      done
      return 1
    }
    # A recent opencode session rooted in the workspace is a resumable
    # conversation even when no process holds the directory: the TUI may exit
    # while a permission prompt is pending, or the client may run elsewhere and
    # be pointed at this worktree. Pending input is in-memory, so the session's
    # last update is the observable signal; the window is OCWS_GC_SESSION_AGE.
    # Guard-silent: a missing database, a missing sqlite3, or a schema change
    # falls back to the process and touch checks.
    session_db="''${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"
    session_age_seconds() {
      v="''${OCWS_GC_SESSION_AGE:-604800}"
      if printf '%s' "$v" | grep -Eq '^[0-9]+$'; then
        printf '%s' "$v"
      else
        echo 604800
      fi
    }
    ws_session_recent() {
      local target="$1" since
      [ -r "$session_db" ] || return 1
      command -v sqlite3 >/dev/null 2>&1 || return 1
      since=$(( ( $(date +%s) - $(session_age_seconds) ) * 1000 ))
      [ -n "$(sqlite3 -cmd '.timeout 2000' "file:$session_db?mode=ro" \
        "select 1 from session_v2 where directory = '$target' and time_archived is null and time_updated >= $since limit 1" 2>/dev/null)" ]
    }
    # True when any entry under the workspace changed at or after the epoch.
    # GNU find's -newermt covers files and directories, so an edit, a new file
    # or a jj snapshot all count as activity, unlike the directory mtime alone.
    ws_touched_since() {
      [ -n "$(find "$1" -newermt "@$2" -print -quit 2>/dev/null)" ]
    }
    # Read-only overview of every workspace and its state. Three renderings
    # share one classification pass: table (the default listing), counts
    # (integers "total empty merged unpushed in-flight conflict stale waitold"
    # for the status badge, where waitold counts parked workspaces past
    # OCWS_WAIT_STALE_DAYS) and board (sections by what needs attention, so a
    # returning user finds the one entry that matters without reading a linear
    # list against the fleet).
    emit_ls() {
      local mode="$1" name state desc root live marker suffix state_display
      local wait_parked wait_created wait_reason wait_days
      local n_total=0 n_empty=0 n_merged=0 n_unpushed=0 n_inflight=0 n_conflict=0 n_stale=0 n_waiting=0 n_waitold=0
      local now
      now="$(date +%s)"
      local rows=()
      local rows_parked=() rows_progress=() rows_review=() rows_conflict=() rows_claimed=() rows_reclaim=()
      while IFS= read -r name; do
        [ -n "$name" ] || continue
        IFS=$'\t' read -r state desc < <(ws_state "$name")
        root="$(realpath -m "$(ws_root_for "$name")")"
        live="-"
        ws_live "$root" && live="live"
        if [ "$live" = "-" ] && { [ "$state" = "empty" ] || [ "$state" = "merged" ]; } && ws_session_recent "$root"; then
          live="session"
        fi

        # Parked: an explicit wait marker overrides the commit state for the
        # display and shields the workspace from gc entirely - the marker
        # outclasses the age gate and the liveness scan below.
        wait_parked=0
        wait_created=0
        wait_reason=""
        marker="$(wait_marker_for "$name")"
        if [ -f "$marker" ]; then
          wait_parked=1
          wait_reason="$(sed -n '1p' "$marker")"
          wait_created="$(sed -n '2p' "$marker")"
          if ! printf '%s' "$wait_created" | grep -Eq '^[0-9]+$'; then wait_created=0; fi
        fi
        wait_days=$(( (now - wait_created) / 86400 ))

        if [ "$wait_parked" = 1 ]; then
          state_display="waiting"
          suffix=""
          [ "$wait_days" -gt 0 ] && suffix=" (''${wait_days}d)"
          desc_display="parked: ''${wait_reason:-(no reason given)}$suffix"
          [ "$state" != "empty" ] && desc_display="$desc_display [jj: $state]"
        else
          state_display="$state"
          desc_display="$desc"
          [ -n "$desc_display" ] || desc_display="(no description set)"
        fi

        if [ "$name" != "default" ]; then
          n_total=$((n_total + 1))
          case "$state" in
            empty) n_empty=$((n_empty + 1)) ;;
            merged) n_merged=$((n_merged + 1)) ;;
            unpushed) n_unpushed=$((n_unpushed + 1)) ;;
            in-flight) n_inflight=$((n_inflight + 1)) ;;
            conflict) n_conflict=$((n_conflict + 1)) ;;
          esac
          if [ "$wait_parked" = 1 ]; then
            n_waiting=$((n_waiting + 1))
            [ "$wait_days" -ge "$(wait_stale_days)" ] && n_waitold=$((n_waitold + 1))
          fi
          # Stale: gc would reclaim it now if not for the age gate - i.e. it
          # is empty/merged and nothing is rooted in it. Live sessions, waiting
          # parkers and young workspaces are excluded so the badge does not nag.
          if [ "$live" = "-" ] && [ "$wait_parked" = 0 ] && { [ "$state" = "empty" ] || [ "$state" = "merged" ]; }; then
            n_stale=$((n_stale + 1))
          fi
          if [ "$wait_parked" = 1 ]; then
            rows_parked+=("$(printf '  %-16s %s' "$name" "$desc_display")")
          else
            case "$state" in
              unpushed) rows_progress+=("$(printf '  %-16s %s' "$name" "$desc_display")") ;;
              in-flight) rows_review+=("$(printf '  %-16s %s' "$name" "$desc_display")") ;;
              conflict) rows_conflict+=("$(printf '  %-16s %s' "$name" "$desc_display")") ;;
              empty | merged)
                if [ "$live" != "-" ]; then
                  rows_claimed+=("$(printf '  %-16s %s' "$name" "$desc_display")")
                else
                  rows_reclaim+=("$(printf '  %-16s %s' "$name" "$desc_display")")
                fi
                ;;
            esac
          fi
        fi
        rows+=("$(printf '  %-18s %-10s %-8s %s' "$name" "$state_display" "$live" "$desc_display")")
      done < <(jj --ignore-working-copy workspace list -T 'name ++ "\n"' 2>/dev/null)

      if [ "$mode" = counts ]; then
        printf '%s %s %s %s %s %s %s %s\n' "$n_total" "$n_empty" "$n_merged" "$n_unpushed" "$n_inflight" "$n_conflict" "$n_stale" "$n_waitold"
        return
      fi

      if [ "$mode" = board ]; then
        echo "ocws board - state derived from jj plus the wait marker and recent sessions; cleanup happens only under RECLAIMABLE"
        if [ "''${#rows_parked[@]}" -gt 0 ]; then
          echo ""
          echo "  PARKED (waiting on the outside world)"
          printf '%s\n' "''${rows_parked[@]}"
        fi
        if [ "''${#rows_progress[@]}" -gt 0 ]; then
          echo ""
          echo "  IN PROGRESS (unpushed)"
          printf '%s\n' "''${rows_progress[@]}"
        fi
        if [ "''${#rows_review[@]}" -gt 0 ]; then
          echo ""
          echo "  IN REVIEW (open PR)"
          printf '%s\n' "''${rows_review[@]}"
        fi
        if [ "''${#rows_conflict[@]}" -gt 0 ]; then
          echo ""
          echo "  NEEDS YOU (conflict)"
          printf '%s\n' "''${rows_conflict[@]}"
        fi
        if [ "''${#rows_claimed[@]}" -gt 0 ]; then
          echo ""
          echo "  CLAIMED (session active)"
          printf '%s\n' "''${rows_claimed[@]}"
        fi
        if [ "''${#rows_reclaim[@]}" -gt 0 ]; then
          echo ""
          echo "  RECLAIMABLE (gc removes once idle and unoccupied)"
          printf '%s\n' "''${rows_reclaim[@]}"
        fi
        return
      fi

      echo "Workspace states:"
      printf '  %-18s %-10s %-8s %s\n' NAME STATE HOLD DESCRIPTION
      printf '%s\n' "''${rows[@]}"
      echo ""
      echo "  empty/merged: reclaimable by 'ocws gc' once idle and unoccupied"
      echo "  HOLD:         live = process rooted here, session = recent opencode session, - = idle"
      echo "  unpushed:     commits outside main@origin no remote bookmark tracks"
      echo "  in-flight:    commits outside main@origin with an open PR"
      echo "  conflict:     needs 'jj resolve'"
      echo "  waiting:      parked with 'ocws wait'; gc keeps until 'ocws go'"
      echo ""
      echo "Summary: $n_empty empty, $n_merged merged, $n_unpushed unpushed, $n_inflight in-flight, $n_conflict conflict, $n_stale stale, $n_waiting waiting ($n_waitold reminder)"
    }
    # Optional lifecycle hook, run with `bash -c` and OCWS_TASK/DIR/ROOT/BASE
    # exported. Env-only so there is no config file to parse. A failing hook is
    # warned about, not fatal: a broken setup step must not strand a workspace
    # or block gc.
    run_hook() {
      local hook="$1" task="$2" dir="$3" cmd="$4"
      [ -n "$cmd" ] || return 0
      OCWS_TASK="$task" OCWS_DIR="$dir" OCWS_ROOT="$root" OCWS_BASE="$base" \
        bash -c "$cmd" || echo "ocws: '$hook' hook failed" >&2
    }
    rip_workspace() {
      local task="$1" dir wait_marker
      dir="$(realpath -m "$(ws_root_for "$task")")"
      if [ "$dir" = "$(realpath -m "$root")" ]; then
        echo "ocws: refusing to remove the current workspace ('$task')" >&2
        exit 1
      fi
      run_hook pre_delete "$task" "$dir" "''${OCWS_HOOK_PRE_DELETE:-}"
      # All three removal paths (done, rm, gc) funnel through here, so the
      # wait marker cannot survive the workspace: insistence on clearing it in
      # each caller would eventually forget one, and a stale marker that pulls
      # a workspace away from gc later would be invisible in `ocws ls`.
      wait_marker="$(wait_marker_for "$task")"
      if [ -f "$wait_marker" ]; then rip "$wait_marker"; fi
      jj workspace forget "$task"
      [ -d "$dir" ] && rip "$dir"
      run_hook post_delete "$task" "$dir" "''${OCWS_HOOK_POST_DELETE:-}"
    }
    # Forget+rip reclaimable workspaces (state empty or merged) that have sat
    # untouched past the age gate and hold no live process, never the current
    # one. An empty unclaimed workspace is pure overhead and gets the shorter
    # OCWS_GC_EMPTY_AGE; a workspace that held work gets the longer
    # OCWS_GC_AGE. A workspace whose recorded directory is gone is forgotten
    # outright, wait marker and all. Parked workspaces (a wait marker) are
    # checked before classification and kept whatever the state mentions, so
    # the marker bypasses every gate below it in this loop. Process liveness, a
    # recent opencode session, and the touch-time gate keep a paused
    # conversation from losing its directory; rip's graveyard makes a mistaken
    # removal restorable regardless.
    # do_fetch=1 fetches first so absorption is judged against current origin.
    ocws_gc() {
      local do_fetch="$1" name dir state desc age_limit now
      local marker wait_reason wait_created wait_days
      now="$(date +%s)"
      # Without main@origin every workspace would classify as empty and be
      # reclaimed. Refuse rather than guess.
      jj --ignore-working-copy log -r 'main@origin' -n 0 >/dev/null 2>&1 || {
        echo "ocws gc: main@origin not found; skipping" >&2
        return 0
      }
      [ "$do_fetch" = 1 ] && { jj git fetch >/dev/null 2>&1 || true; }
      while IFS= read -r name; do
        [ "$name" = "default" ] && continue
        dir="$(realpath -m "$(ws_root_for "$name")")"
        [ "$dir" = "$(realpath -m "$root")" ] && continue

        if [ ! -d "$dir" ]; then
          rip_workspace "$name"
          echo "ocws gc: forgot '$name' (directory missing)"
          continue
        fi

        # Parked: a wait marker keeps the workspace out of every gate below,
        # whatever its commit state, because the reason lives outside jj - a
        # session waiting on the outside world looks empty and unoccupied.
        marker="$(wait_marker_for "$name")"
        if [ -f "$marker" ]; then
          wait_reason="$(sed -n '1p' "$marker")"
          wait_created="$(sed -n '2p' "$marker")"
          if ! printf '%s' "$wait_created" | grep -Eq '^[0-9]+$'; then wait_created=0; fi
          echo "ocws gc: keeping '$name' (parked: ''${wait_reason:-(no reason given)})"
          wait_days=$(( (now - wait_created) / 86400 ))
          if [ "$wait_days" -ge "$(wait_stale_days)" ]; then
            echo "ocws gc: '$name' has waited $wait_days days - resume it ('ocws go $name') or release the workspace"
          fi
          continue
        fi

        IFS=$'\t' read -r state desc < <(ws_state "$name")
        case "$state" in
          unpushed) echo "ocws gc: keeping '$name' (unpushed work)"; continue ;;
          in-flight) echo "ocws gc: keeping '$name' (open PR)"; continue ;;
          conflict) echo "ocws gc: keeping '$name' (conflict)" >&2; continue ;;
        esac

        if ws_live "$dir"; then
          echo "ocws gc: keeping '$name' (live process)"
          continue
        fi

        if ws_session_recent "$dir"; then
          echo "ocws gc: keeping '$name' (recent session)"
          continue
        fi

        if [ "$state" = "empty" ] && [ -z "$desc" ]; then
          age_limit="''${OCWS_GC_EMPTY_AGE:-21600}"
        else
          age_limit="''${OCWS_GC_AGE:-86400}"
        fi
        ws_touched_since "$dir" "$((now - age_limit))" && continue

        rip_workspace "$name"
        echo "ocws gc: forgot '$name' ($state)"
      done < <(jj --ignore-working-copy workspace list -T 'name ++ "\n"' 2>/dev/null)
    }

    sub="''${1:-}"
    [ -n "$sub" ] || usage

    # Optional leading flag: run the opencode 2 beta instead of V1.
    if [ "$sub" = "--v2" ]; then
      OCWS_V2=1
      shift
      sub="''${1:-}"
      [ -n "$sub" ] || usage
    fi

    case "$sub" in
      wait)
        shift
        task="''${1:-}"
        [ -n "$task" ] || usage
        valid_task "$task" || { echo "ocws: invalid task '$task' (use [A-Za-z0-9._-])" >&2; exit 2; }
        workspace_exists "$task" || { echo "ocws: no workspace named '$task'" >&2; exit 1; }
        [ "$task" = "default" ] && { echo "ocws wait: the primary checkout is the user's, not an agent workspace to park" >&2; exit 1; }
        shift || true
        reason="$*"
        printf '%s\n%s\n' "$reason" "$(date +%s)" > "$(wait_marker_for "$task")"
        echo "ocws: '$task' parked (''${reason:-(no reason given)}) - gc keeps it; resume with 'ocws go $task'"
        exit 0
        ;;
      go)
        shift
        task="''${1:-}"
        [ -n "$task" ] || usage
        valid_task "$task" || { echo "ocws: invalid task '$task' (use [A-Za-z0-9._-])" >&2; exit 2; }
        workspace_exists "$task" || { echo "ocws: no workspace named '$task'" >&2; exit 1; }
        [ "$task" = "default" ] && { echo "ocws go: the primary checkout is the user's, not an agent workspace" >&2; exit 1; }
        wait_marker="$(wait_marker_for "$task")"
        if [ ! -f "$wait_marker" ]; then
          echo "ocws: '$task' is not parked" >&2
          exit 1
        fi
        rip "$wait_marker"
        echo "ocws: '$task' resumed; gc reclassifies it on the next pass"
        exit 0
        ;;
      title)
        shift
        text="$*"
        [ -n "$text" ] || usage
        # The seat runs in its own workspace, so the directory identifies the
        # task: jj records workspace roots absolutely, and a prefix match also
        # covers a command run from a subdirectory. Read the list once: a
        # pipeline here would let an early `break` SIGPIPE jj, and pipefail
        # would then abort the claim.
        here="$(realpath -m "$PWD")"
        names="$(jj --ignore-working-copy workspace list -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null)"
        task=""
        while IFS=$'\t' read -r name ws_root; do
          case "$here/" in
            "$(realpath -m "$ws_root")/"*)
              task="$name"
              break
              ;;
          esac
        done <<<"$names"
        [ -n "$task" ] || { echo "ocws title: not inside a registered workspace" >&2; exit 1; }
        # `default` is the coordinator and the anchor the boundaries alias keys
        # off (`default@`), so a stray claim from the primary checkout must not
        # rename it.
        [ "$task" = "default" ] && { echo "ocws title: the primary checkout is not a seat" >&2; exit 1; }
        # Only the placeholder `jj workspace add` wrote is replaceable. Match
        # its shape, not the name, so a retry finishes a claim whose rename
        # already landed. Once a human or an agent described the change, the
        # claim is theirs.
        desc="$(jj --ignore-working-copy log --no-graph -r @ -T 'description.first_line()' 2>/dev/null)"
        if ! grep -Eq '^t-[0-9]{4,6}(-[0-9])?: started from main@origin$' <<<"$desc"; then
          exit 0
        fi
        slug="$(printf '%s' "$text" \
          | tr '[:upper:]' '[:lower:]' \
          | tr -cs '[:alnum:]' '-' \
          | sed -e 's/^-*//' -e 's/-*$//' \
          | cut -c1-48 \
          | sed -e 's/-*$//')"
        [ -n "$slug" ] || exit 0
        # Workspace names are the handle other sessions read, so a second seat
        # with the same title must not collide with the first.
        taken() {
          local existing
          while IFS=$'\t' read -r existing _; do
            if [ "$existing" = "$1" ]; then return 0; fi
          done <<<"$names"
          return 1
        }
        final="$slug"
        n=2
        while taken "$final"; do
          final="$slug-$n"
          n=$((n + 1))
          [ "$n" -gt 9 ] && break
        done
        # Rename before describing: a refused rename (a name race) then leaves
        # the placeholder intact and the next call retries the whole claim.
        jj workspace rename "$final"
        jj describe -m "$text"
        if [ -n "''${HERDR_TAB_ID:-}" ] && command -v herdr >/dev/null 2>&1; then
          herdr tab rename "$HERDR_TAB_ID" "$final" >/dev/null 2>&1 || true
        fi
        echo "ocws: claimed '$task' as '$final'"
        exit 0
        ;;
      ls|list)
        shift
        counts=0
        board=0
        if [ "''${1:-}" = "--counts" ]; then
          counts=1
          shift
        fi
        if [ "''${1:-}" = "--board" ]; then
          board=1
          shift
        fi
        if [ "$counts" = 0 ] && [ "$board" = 0 ]; then
          jj --ignore-working-copy workspace list
          echo ""
        fi
        if [ "$counts" = 1 ]; then emit_ls counts; elif [ "$board" = 1 ]; then emit_ls board; else emit_ls table; fi
        exit 0
        ;;
      gc)
        shift
        ocws_gc 1
        exit 0
        ;;
      done)
        shift
        force=0
        if [ "''${1:-}" = "--force" ]; then force=1; shift; fi
        task="''${1:-}"
        [ -n "$task" ] || usage
        valid_task "$task" || { echo "ocws: invalid task '$task'" >&2; exit 2; }
        workspace_exists "$task" || { echo "ocws: no workspace named '$task'" >&2; exit 1; }
        jj git fetch >/dev/null 2>&1 || true
        if ws_has_work "$task"; then
          echo "ocws: '$task' still has unmerged/uncommitted work; refusing to remove." >&2
          jj --ignore-working-copy log --no-graph -r "ancestors($task@) ~ ::main@origin ~ empty()" -T '"  " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"' >&2
          echo "Merge the PR, then retry; or 'ocws rm --force $task' to discard." >&2
          exit 1
        fi
        # A session can still hold the directory after its work merged; a
        # removal under an open session strands it, so require --force then.
        if [ "$force" != "1" ] && ws_live "$(realpath -m "$(ws_root_for "$task")")"; then
          echo "ocws: a process is still active in '$task'; close it first, or 'ocws done --force $task'." >&2
          exit 1
        fi
        rip_workspace "$task"
        echo "Done: forgot '$task' (directory sent to the graveyard)."
        exit 0
        ;;
      rm|forget)
        shift
        force=0
        if [ "''${1:-}" = "--force" ]; then force=1; shift; fi
        task="''${1:-}"
        [ -n "$task" ] || usage
        valid_task "$task" || { echo "ocws: invalid task '$task'" >&2; exit 2; }
        workspace_exists "$task" || { echo "ocws: no workspace named '$task'" >&2; exit 1; }
        if [ "$force" != "1" ]; then
          if ws_has_work "$task"; then
            echo "ocws: '$task' has unmerged/uncommitted work; use 'ocws done $task' after merging, or 'ocws rm --force $task' to discard." >&2
            exit 1
          fi
          if ws_live "$(realpath -m "$(ws_root_for "$task")")"; then
            echo "ocws: a process is still active in '$task'; close it first, or 'ocws rm --force $task'." >&2
            exit 1
          fi
        fi
        rip_workspace "$task"
        echo "Forgot '$task' (directory sent to the graveyard)."
        exit 0
        ;;
      herdr)
        shift
        # A herdr tab is only a layout: with terminal.new_cwd = follow it
        # inherits the focused pane's worktree, so running opencode in a bare
        # tab shares that working copy. This subcommand creates the tab and
        # starts the agent there through the same creation path as `ocws`, so
        # a seat always gets its own jj workspace. An existing workspace is
        # reopened only when no process is live in it; a second agent in one
        # working copy is the interference this workflow exists to prevent.
        #
        # The seat runs from a herdr popup, and a popup closes the moment its
        # command exits: an empty or invalid answer must re-ask instead of
        # exiting, and a failure after the prompt must hold the popup open
        # for a keypress, or the user sees only a flash of text.
        seat_log="''${XDG_CACHE_HOME:-$HOME/.cache}/ocws/seat.log"
        fail() {
          printf 'ocws herdr: %s\n' "$*" >&2
          if [ -t 0 ]; then
            read -r -p 'press enter to close ' _ || true
          else
            # The detached binding has no terminal to show the error in, so
            # keep it where the next diagnosis will look.
            mkdir -p "$(dirname "$seat_log")"
            printf '%s %s\n' "$(date -Is)" "$*" >> "$seat_log"
          fi
          exit 1
        }
        task="''${1:-}"
        if [ -n "$task" ]; then
          shift
        else
          # The keypress is the interrupt: a name prompt would put a dialog in
          # front of every seat. An unnamed seat gets a filler that
          # `ocws title` replaces once OpenCode names the session.
          task="t-$(date +%H%M%S)"
          n=2
          while workspace_exists "$task"; do
            task="t-$(date +%H%M%S)-$n"
            n=$((n + 1))
            [ "$n" -gt 9 ] && break
          done
        fi
        valid_task "$task" || { echo "ocws herdr: invalid task '$task' (use [A-Za-z0-9._-])" >&2; exit 2; }
        extra=()
        if [ "''${1:-}" = "--" ]; then
          shift
          extra=("$@")
        elif [ "$#" -gt 0 ]; then
          usage
        fi
        # herdr exports HERDR_BIN_PATH to custom command keybindings, which is
        # where the seat popup runs; outside one, fall back to the PATH name.
        herdr_bin="''${HERDR_BIN_PATH:-herdr}"
        command -v "$herdr_bin" >/dev/null 2>&1 || fail "herdr binary not found: $herdr_bin"

        if workspace_exists "$task"; then
          dir="$(realpath -m "$(ws_root_for "$task")")"
          if ws_live "$dir"; then
            fail "'$task' already has a live session in $dir; refusing a second agent in the same workspace"
          fi
          if [ "''${OCWS_V2:-0}" = "1" ]; then
            inner="cd $(printf '%q' "$dir") && exec $(printf '%q' opencode2)"
          else
            inner="cd $(printf '%q' "$dir") && exec $(printf '%q' opencode)"
          fi
          for arg in "''${extra[@]}"; do
            inner+=" $(printf '%q' "$arg")"
          done
        else
          self="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
          # The seat is created for speed: skip the gc pass and the network
          # fetch the create path would otherwise run before `workspace add`.
          inner="OCWS_NO_MAINT=1 $(printf '%q' "$self")"
          [ "''${OCWS_V2:-0}" = "1" ] && inner+=" --v2"
          inner+=" $(printf '%q' "$task")"
          if [ "''${#extra[@]}" -gt 0 ]; then
            inner+=" --"
            for arg in "''${extra[@]}"; do
              inner+=" $(printf '%q' "$arg")"
            done
          fi
        fi

        # The tab starts at a jj workspace root: ocws resolves the repository
        # with `jj workspace root`, and the workspace base is outside it. The
        # agent still starts only in the workspace ocws creates (or the existing
        # one it cd's to); nothing runs in the tab's initial directory.
        tab_args=(tab create --cwd "$root" --label "$task" --focus)
        if ! resp="$("$herdr_bin" "''${tab_args[@]}" 2>&1)"; then
          fail "cannot create a herdr tab: $resp"
        fi
        pane="$(printf '%s' "$resp" | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null || true)"
        [ -n "$pane" ] || fail "herdr did not return a root pane: $resp"
        if ! "$herdr_bin" pane run "$pane" "$inner"; then
          fail "tab created, but the agent did not start; run 'ocws $task' in it"
        fi
        exit 0
        ;;
      tab)
        new_tab=1
        shift
        ;;
      *)
        new_tab=0
        ;;
    esac

    task="''${1:-}"
    [ -n "$task" ] || usage
    shift || true
    [ "''${1:-}" = "--" ] && shift
    valid_task "$task" || { echo "ocws: invalid task '$task' (use [A-Za-z0-9._-])" >&2; exit 2; }

    dir="$(ws_dir_for "$task")"
    if workspace_exists "$task"; then
      echo "ocws: workspace '$task' already exists - 'ocws rm $task' to recreate it" >&2
      exit 1
    fi
    [ -e "$dir" ] && { echo "ocws: path already exists: $dir" >&2; exit 1; }

    # Maintenance is skipped when an interactive seat asks for a workspace: a
    # full classification plus a network fetch costs seconds, and the seat must
    # appear on the keypress. The daily timer owns reclamation and `jjwork`
    # fetches before any real work.
    if [ "''${OCWS_NO_MAINT:-0}" != "1" ]; then
      # Opportunistically reclaim finished workspaces before adding a new one.
      # Best-effort: a gc failure must never block workspace creation. Skips
      # the fetch (do_fetch=0) because the create path fetches below.
      ocws_gc 0 || true
    fi

    run_hook pre_create "$task" "$dir" "''${OCWS_HOOK_PRE_CREATE:-}"

    if [ "''${OCWS_NO_MAINT:-0}" != "1" ]; then
      jj git fetch >/dev/null 2>&1 || true
    fi
    jj workspace add "$dir" --name "$task" -r 'main@origin' -m "$task: started from main@origin"

    run_hook post_create "$task" "$dir" "''${OCWS_HOOK_POST_CREATE:-}"

    # Herdr tab labels are the navigation key (goto picker, expanded sidebar).
    # Name the seat after the task so a new tab reads as the task, not as a
    # generic shell. Guard-silent: HERDR_TAB_ID is unset outside a herdr pane,
    # and a failed rename must never block the launch.
    if [ -n "''${HERDR_TAB_ID:-}" ] && command -v herdr >/dev/null 2>&1; then
      herdr tab rename "$HERDR_TAB_ID" "$task" >/dev/null 2>&1 || true
    fi

    if [ "''${OCWS_V2:-0}" = "1" ]; then
      # Both names resolve to the same launcher, which pins the config root and
      # its database itself; the flag is kept for existing invocations.
      run=(opencode2 "$@")
    else
      run=(opencode "$@")
    fi

    if [ "$new_tab" = "1" ]; then
      if [ -z "''${ZELLIJ_SESSION_NAME:-}" ]; then
        echo "ocws: 'tab' must run inside a zellij session" >&2
        exit 1
      fi
      zellij action new-tab --name "$task" --cwd "$dir" -- "''${run[@]}"
    else
      cd "$dir"
      exec "''${run[@]}"
    fi
  '';
}
