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
  direnv,
  gnugrep,
  gnused,
  findutils,
  rip2,
  zellij,
  jq,
  sqlite,
  util-linux,
  bash,
}:
writeShellApplication {
  name = "ocws";
  runtimeInputs = [
    jujutsu
    coreutils
    direnv
    gnugrep
    gnused
    findutils
    rip2
    zellij
    jq
    sqlite
    util-linux
    bash
  ];
  text = ''
    set -euo pipefail

    usage() {
      cat >&2 <<'USAGE'
    Usage:
      ocws <task> [-- <opencode args>...]   create a workspace and run opencode there
      ocws tab <task> [-- <opencode args>]  create a workspace in a new zellij tab
      ocws herdr [--json] [--no-focus] [--workspace ID] [--wait[=SECONDS]] [<task>] [-- <opencode args>]
                                            start an agent seat: create the workspace
                                            and run opencode in a new herdr tab; an
                                            unnamed seat gets a filler task that
                                            'ocws title' replaces. --json prints the
                                            tab, pane and workspace for a lead;
                                            --no-focus keeps the person's view still;
                                            --wait blocks until the agent is at its
                                            prompt (180s by default)
      ocws seat [--json]                    print the calling agent's herdr workspace,
                                            tab and pane, matched by OPENCODE_SESSION_ID
      ocws title <text...>                  claim the current seat: set the change
                                            description, rename the workspace and the
                                            herdr tab from the session title; a no-op
                                            unless the description is still the filler
      ocws ls [--counts|--board] [--refresh]
                                            list workspaces with their state and claim
                                            (--counts prints the integers "total empty merged
                                            unpushed in-flight conflict stale waitold", where
                                            waitold counts parked workspaces older than
                                            OCWS_WAIT_STALE_DAYS; --board groups the same
                                            classification into "what needs you" sections;
                                            --refresh ignores the classification cache and
                                            scans now, rewriting it)
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
      OCWS_BOARD_JOBS
                    parallel workers for the board's absorption checks and its
                    process/session probes (default 8, clamped to 1-32)
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
    # Exit 2 means the check itself failed (a jj error, or a commit that
    # vanished mid-scan): callers must treat that as work still present, never
    # as absorbed, or a transient failure would hide unpushed content.
    ws_commit_absorbed() {
      local cid="$1" out
      local -a files=()
      out="$(jj --ignore-working-copy diff -r "$cid" --name-only 2>/dev/null)" || return 2
      [ -n "$out" ] || return 0
      mapfile -t files <<<"$out"
      out="$(jj --ignore-working-copy diff --from 'main@origin' --to "$cid" -- "''${files[@]}" 2>/dev/null)" || return 2
      [ -z "$out" ]
    }
    # Classification of one workspace from the commits reachable from its @
    # that carry content outside main@origin. The state is one of:
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
    #
    # A board scan computes absorption in a bounded parallel pool and points
    # absorb_dir at the per-commit results; gc and the removal paths leave it
    # empty and pay the checks inline. classify_ok turns false when an input
    # could not be read, so the board refuses to cache a guessed state.
    absorb_dir=""
    classify_ok=1
    absorbed_of() {
      local cid="$1" path
      if [ -n "$absorb_dir" ]; then
        path="$absorb_dir/absorbed-$cid"
        if [ -r "$path" ]; then
          printf '%s' "$(<"$path")"
        else
          printf '2'
        fi
        return 0
      fi
      ws_commit_absorbed "$cid" || {
        printf '%s' "$?"
        return 0
      }
      printf '0'
    }
    # Interpret one workspace's ancestry flag lines ("<commit_id> <flags>")
    # and set st_state. Flags carry C (conflict), E (empty), R (remote
    # bookmark) and M (contained in main@origin). Together the lines are the
    # old revset "T | (ancestors(T) ~ ::main@origin)": a main commit appears
    # only as the workspace target itself, which is why M skips content (an
    # edited main commit is not off-main work) but stops the ancestry walk.
    state_from_flags() {
      local cid flags has_work=0 has_remote=0 offmain=0 stat
      st_conflict=0
      while read -r cid flags; do
        [ -n "$cid" ] || continue
        case "$flags" in *C*) st_conflict=1 ;; esac
        case "$flags" in *M*) continue ;; esac
        case "$flags" in
          *E*) ;;
          *)
            offmain=1
            case "$flags" in *R*) has_remote=1 ;; esac
            stat="$(absorbed_of "$cid")"
            case "$stat" in
              0) ;;
              1) has_work=1 ;;
              *)
                has_work=1
                classify_ok=0
                ;;
            esac
            ;;
        esac
      done
      if [ "$st_conflict" = 1 ]; then
        st_state=conflict
      elif [ "$offmain" = 0 ]; then
        st_state=empty
      elif [ "$has_work" = 0 ]; then
        st_state=merged
      elif [ "$has_remote" = 1 ]; then
        st_state=in-flight
      else
        st_state=unpushed
      fi
    }
    # Classify a workspace with one jj call. Prints "<state>\t<desc>". The
    # optional second argument is an already-known description (the board has
    # it from the workspace list), which saves one jj process per workspace.
    # Non-zero means the classification input was unreadable; callers must not
    # treat that as any particular state.
    ws_state() {
      local name="$1" rev="$1@" desc lines have_desc=0
      if [ "$#" -ge 2 ]; then
        have_desc=1
        desc="$2"
      fi
      if [ "$have_desc" = 0 ]; then
        desc="$(jj --ignore-working-copy log --no-graph -r "$rev" -T 'description.first_line()' 2>/dev/null)" || return 1
      fi
      lines="$(jj --ignore-working-copy log --no-graph -r "$rev | (ancestors($rev) ~ ::main@origin)" \
        -T 'commit_id ++ " " ++ if(self.conflict(), "C", "-") ++ if(self.empty(), "E", "-") ++ if(self.remote_bookmarks(), "R", "-") ++ if(self.contained_in("::main@origin"), "M", "-") ++ "\n"' 2>/dev/null)" || return 1
      [ -n "$lines" ] || return 1
      state_from_flags <<<"$lines"
      printf '%s\t%s\n' "$st_state" "$desc"
    }
    # A workspace "has work" when its state holds content not yet on
    # main@origin. done/rm refuse to reclaim such a workspace; an unreadable
    # classification counts as work, so a transient jj failure cannot turn a
    # removal into data loss.
    ws_has_work() {
      local out
      out="$(ws_state "$1")" || return 0
      case "''${out%%$'\t'*}" in
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
    #
    # /proc is captured once per invocation. The old per-workspace loop forked
    # readlink for every PID of every workspace, about ten seconds on a 37
    # workspace fleet; one find pass resolves every readable cwd and indexes
    # each one under all of its ancestors, so a workspace lookup is an array
    # read plus a cmdline check for its own processes. The board snapshots
    # concurrently with its jj calls and hands the file to proc_load; gc falls
    # back to proc_scan on first use.
    live_exclude='(^|/)[^ ]*(mcp-[a-z0-9._-]+-wrapped|nix-language-server)[^ ]*'
    [ -n "''${OCWS_LIVE_EXCLUDE:-}" ] && live_exclude="$live_exclude|''${OCWS_LIVE_EXCLUDE}"
    declare -A proc_pids_of=()
    declare -A board_roots=()
    proc_loaded=0
    proc_load() {
      local path cwd pid dir
      proc_loaded=1
      while IFS=$'\t' read -r path cwd; do
        [ -n "$cwd" ] || continue
        pid="''${path#/proc/}"
        pid="''${pid%%/*}"
        dir="$cwd"
        if [ "''${#board_roots[@]}" -eq 0 ]; then
          # Unrestricted (gc): index every ancestor, so any later workspace
          # lookup is one array read.
          while [ -n "$dir" ] && [ "$dir" != / ]; do
            proc_pids_of["$dir"]+="$pid "
            dir="''${dir%/*}"
          done
          continue
        fi
        # Restricted (the board): the caller filtered the snapshot to the
        # workspace parents, so attribute each line to its deepest root.
        while [ -n "$dir" ] && [ "$dir" != / ]; do
          if [ -n "''${board_roots[$dir]:-}" ]; then
            proc_pids_of["$dir"]+="$pid "
            break
          fi
          dir="''${dir%/*}"
        done
      done
    }
    proc_scan() {
      [ "$proc_loaded" = 1 ] && return 0
      proc_load < <(find /proc/[0-9]*/cwd -maxdepth 0 -printf '%p\t%l\n' 2>/dev/null || true)
    }
    ws_live() {
      local target="$1" pid cmd
      local -a argv=()
      proc_scan
      for pid in ''${proc_pids_of[$target]:-}; do
        argv=()
        mapfile -d "" -t argv 2>/dev/null < "/proc/$pid/cmdline" || argv=()
        cmd="''${argv[*]}"
        [[ $cmd =~ $live_exclude ]] && continue
        return 0
      done
      return 1
    }
    # A recent opencode session rooted in the workspace is a resumable
    # conversation even when no process holds the directory: the TUI may exit
    # while a permission prompt is pending, or the client may run elsewhere and
    # be pointed at this worktree. Pending input is in-memory, so the session's
    # last update is the observable signal; the window is OCWS_GC_SESSION_AGE.
    # Guard-silent: a missing database, a missing sqlite3, or a schema change
    # falls back to the process and touch checks. One query covers every
    # directory, instead of one sqlite process per workspace.
    session_db="''${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"
    session_age_seconds() {
      v="''${OCWS_GC_SESSION_AGE:-604800}"
      if printf '%s' "$v" | grep -Eq '^[0-9]+$'; then
        printf '%s' "$v"
      else
        echo 604800
      fi
    }
    declare -A session_dirs=()
    session_loaded=0
    session_query() {
      local since
      [ -r "$session_db" ] || return 0
      command -v sqlite3 >/dev/null 2>&1 || return 0
      since=$(( ( $(date +%s) - $(session_age_seconds) ) * 1000 ))
      sqlite3 -cmd '.timeout 2000' "file:$session_db?mode=ro" \
        "select distinct directory from session_v2 where time_archived is null and time_updated >= $since" 2>/dev/null || true
    }
    session_load() {
      local dir
      session_loaded=1
      while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        # The board knows its roots, so only those directories earn an
        # associative entry; gc (no root set) keeps them all.
        if [ "''${#board_roots[@]}" -eq 0 ] || [ -n "''${board_roots[$dir]:-}" ]; then
          session_dirs["$dir"]=1
        fi
      done
    }
    ws_session_recent() {
      [ "$session_loaded" = 1 ] || session_load < <(session_query)
      [ -n "''${session_dirs[$1]:-}" ]
    }
    # True when any entry under the workspace changed at or after the epoch.
    # GNU find's -newermt covers files and directories, so an edit, a new file
    # or a jj snapshot all count as activity, unlike the directory mtime alone.
    ws_touched_since() {
      [ -n "$(find "$1" -newermt "@$2" -print -quit 2>/dev/null)" ]
    }
    # --- board classification and its cache -------------------------------

    # States are the only thing cached: they are a pure function of the jj
    # operation, main@origin and the workspace targets in the key. Anything
    # that changes without a jj operation - processes, recent sessions, wait
    # markers - is recomputed on every run, so a cache hit cannot show a stale
    # hold. The key moves on a commit or description change (the workspace
    # list carries each target commit), a bookmark move or fetch (the op id
    # and main@origin), and a workspace add, forget or rename (the list).
    # A cache hit is exact, not time based. Bump the v1 header whenever the
    # state logic changes: the key cannot see a code change by itself.
    board_tmp=""
    board_lock_fd=""
    board_cache_dir=""
    board_cache_file=""
    board_lock_file=""
    declare -A board_states=()
    declare -A cls_parent_of=()
    declare -A cls_flags_of=()
    declare -A cls_target_of=()
    trap '[ -n "$board_tmp" ] && rm -rf "$board_tmp" || true' EXIT

    board_jobs() {
      local v="''${OCWS_BOARD_JOBS:-8}"
      printf '%s' "$v" | grep -Eq '^[0-9]{1,3}$' || v=8
      if [ "$v" -lt 1 ]; then v=8; fi
      if [ "$v" -gt 32 ]; then v=32; fi
      printf '%s' "$v"
    }
    # A missing, corrupt or unreadable cache is simply a miss: the board must
    # never fail because of it.
    board_cache_load() {
      local key="$1" body line name st
      board_states=()
      [ -r "$board_cache_file" ] || return 1
      body="$(<"$board_cache_file")" || return 1
      line="''${body%%$'\n'*}"
      [ "$line" = "v1 $key" ] || return 1
      body="''${body#*$'\n'}"
      while IFS=$'\t' read -r name st; do
        [ -n "$name" ] || continue
        case "$st" in
          empty | merged | unpushed | in-flight | conflict) board_states["$name"]="$st" ;;
          *)
            board_states=()
            return 1
            ;;
        esac
      done <<<"$body"
      for name in "''${ws_names[@]}"; do
        if [ -z "''${board_states[$name]+x}" ]; then
          board_states=()
          return 1
        fi
      done
      return 0
    }
    # Write through a temp file in the same directory and rename, so a reader
    # sees either the old cache or the new one, never a partial file.
    board_cache_store() {
      local key="$1" file name
      mkdir -p "$board_cache_dir" 2>/dev/null || return 0
      file="$(mktemp "$board_cache_file.XXXXXX" 2>/dev/null)" || return 0
      {
        printf 'v1 %s\n' "$key"
        for name in "''${ws_names[@]}"; do
          printf '%s\t%s\n' "$name" "''${board_states[$name]}"
        done
      } >"$file" 2>/dev/null || {
        rm -f "$file"
        return 0
      }
      mv -f "$file" "$board_cache_file" 2>/dev/null || rm -f "$file"
      return 0
    }
    # Hold the scan lock so two popups do not classify at once. A popup must
    # not hang: after two seconds the caller classifies without the lock, and
    # the atomic rename makes a duplicate write harmless. flock releases on
    # process death, which a marker-directory lock would not.
    board_lock() {
      command -v flock >/dev/null 2>&1 || return 1
      mkdir -p "$board_cache_dir" 2>/dev/null || return 1
      exec {board_lock_fd}>"$board_lock_file" 2>/dev/null || {
        board_lock_fd=""
        return 1
      }
      if flock -w 2 "$board_lock_fd"; then
        return 0
      fi
      exec {board_lock_fd}>&- 2>/dev/null || true
      board_lock_fd=""
      return 1
    }
    board_unlock() {
      if [ -n "$board_lock_fd" ]; then
        exec {board_lock_fd}>&- 2>/dev/null || true
      fi
      board_lock_fd=""
    }
    # One jj log over every workspace target and every off-main commit
    # reachable from one. The template carries parent edges plus the C/E/R/M
    # flags and attributes exact targets through working_copies(), so no
    # workspace name enters a revset or a generated template, and the cost
    # scales with commits rather than workspaces times commits. Absorption is
    # the only per-commit jj work left and runs in a bounded pool; its results
    # land in absorbed-<commit> files that absorbed_of reads.
    board_classify() {
      local dir="$1" cid parents flags targets name
      local -a commit_ids=() tnames=() pids=()
      local jobs
      classify_ok=1
      board_states=()
      cls_parent_of=()
      cls_flags_of=()
      cls_target_of=()
      if ! jj --ignore-working-copy log --no-graph \
        -r 'working_copies() | (main@origin..working_copies())' \
        -T 'commit_id ++ "\t" ++ self.parents().map(|p| p.commit_id()).join(",") ++ "\t" ++ if(self.conflict(), "C", "-") ++ if(self.empty(), "E", "-") ++ if(self.remote_bookmarks(), "R", "-") ++ if(self.contained_in("::main@origin"), "M", "-") ++ "\t" ++ self.working_copies().map(|w| w.name()).join(",") ++ "\n"' \
        >"$dir/fleet" 2>/dev/null; then
        echo "ocws: cannot classify workspaces" >&2
        return 1
      fi
      while IFS=$'\t' read -r cid parents flags targets; do
        [ -n "$cid" ] || continue
        cls_parent_of["$cid"]="$parents"
        cls_flags_of["$cid"]="$flags"
        IFS=',' read -r -a tnames <<<"$targets"
        for name in "''${tnames[@]}"; do
          [ -n "$name" ] && cls_target_of["$name"]="$cid"
        done
        case "$flags" in
          *M* | *E*) ;;
          *) commit_ids+=("$cid") ;;
        esac
      done <"$dir/fleet"

      jobs="$(board_jobs)"
      for cid in "''${commit_ids[@]}"; do
        (
          if ws_commit_absorbed "$cid"; then
            printf '0'
          else
            printf '%s' "$?"
          fi
        ) >"$dir/absorbed-$cid" 2>/dev/null &
        pids+=($!)
        if [ "''${#pids[@]}" -ge "$jobs" ]; then
          wait "''${pids[0]}" || true
          pids=("''${pids[@]:1}")
        fi
      done
      wait
      absorb_dir="$dir"
      for name in "''${ws_names[@]}"; do
        if ! board_state_for "$name"; then
          echo "ocws: cannot classify workspace '$name'" >&2
          absorb_dir=""
          return 1
        fi
        board_states["$name"]="$st_state"
      done
      absorb_dir=""
      return 0
    }
    # Rebuild the per-workspace line set ws_state would get from jj: the
    # target plus the off-main commits reachable from it. A main commit is
    # included only as the target itself and stops the walk, which matches
    # "T | (ancestors(T) ~ ::main@origin)". Order never matters here, so the
    # fleet scan needs no worker ordering.
    board_state_for() {
      local name="$1" start="''${cls_target_of[$1]:-}" cid parents flags lines=""
      local -a queue=() seen=()
      [ -n "$start" ] || return 1
      queue=("$start")
      while [ "''${#queue[@]}" -gt 0 ]; do
        cid="''${queue[0]}"
        queue=("''${queue[@]:1}")
        if [ -z "''${cls_flags_of[$cid]+x}" ]; then continue; fi
        case " ''${seen[*]} " in
          *" $cid "*) continue ;;
        esac
        seen+=("$cid")
        flags="''${cls_flags_of[$cid]}"
        if [ "$cid" != "$start" ]; then
          case "$flags" in *M*) continue ;; esac
        fi
        lines+="$cid $flags"$'\n'
        case "$flags" in *M*) continue ;; esac
        for parents in ''${cls_parent_of[$cid]}; do
          queue+=("$parents")
        done
      done
      state_from_flags <<<"$lines"
      return 0
    }
    # Read-only overview of every workspace and its state. Three renderings
    # share one classification pass: table (the default listing), counts
    # (integers "total empty merged unpushed in-flight conflict stale waitold"
    # for the status badge, where waitold counts parked workspaces past
    # OCWS_WAIT_STALE_DAYS) and board (sections by what needs attention, so a
    # returning user finds the one entry that matters without reading a linear
    # list against the fleet).
    emit_ls() {
      local mode="$1" refresh="$2"
      local name state desc ws_root live marker suffix state_display
      local target
      local wait_parked wait_created wait_reason wait_days
      local n_total=0 n_empty=0 n_merged=0 n_unpushed=0 n_inflight=0 n_conflict=0 n_stale=0 n_waiting=0 n_waitold=0
      local now stale_days i
      local op_id main_cid repo_path repo_id key hit
      local -a ws_names=() roots=() descs=() targets=() raw_roots=()
      local rows=()
      local row
      local rows_parked=() rows_progress=() rows_review=() rows_conflict=() rows_claimed=() rows_reclaim=()
      local tmp
      now="$(date +%s)"
      stale_days="$(wait_stale_days)"
      tmp="$(mktemp -d 2>/dev/null)" || {
        echo "ocws: cannot create a working directory" >&2
        return 1
      }
      board_tmp="$tmp"
      # The workspace list, the cache-key calls and the session probe are
      # independent; starting them together hides the probe and key cost
      # behind the jj calls. The probes are loaded only after the
      # classification and are never cached.
      (
        session_query >"$tmp/sessions" || true
      ) &
      (
        jj --ignore-working-copy workspace list \
          -T 'name ++ "\t" ++ root ++ "\t" ++ target.commit_id() ++ "\t" ++ target.description().first_line() ++ "\n"' \
          >"$tmp/ws" 2>/dev/null || true
      ) &
      (
        jj --ignore-working-copy op log --no-graph -n 1 -T 'id' >"$tmp/op" 2>/dev/null || true
      ) &
      (
        jj --ignore-working-copy log --no-graph -r 'main@origin' -T 'commit_id' >"$tmp/main" 2>/dev/null || true
      ) &
      (
        jj config path --repo >"$tmp/repopath" 2>/dev/null || true
      ) &
      wait
      if [ ! -s "$tmp/ws" ]; then
        echo "ocws: cannot list jj workspaces" >&2
        return 1
      fi
      while IFS=$'\t' read -r name ws_root target desc; do
        [ -n "$name" ] || continue
        ws_names+=("$name")
        targets+=("$target")
        descs+=("$desc")
        if [ -n "$ws_root" ] && [ "$ws_root" != none ]; then
          raw_roots+=("$ws_root")
        else
          raw_roots+=("$(ws_dir_for "$name")")
        fi
      done <"$tmp/ws"
      if [ "''${#ws_names[@]}" -eq 0 ]; then
        echo "ocws: no jj workspaces found" >&2
        return 1
      fi
      mapfile -t roots < <(realpath -m -- "''${raw_roots[@]}")
      if [ "''${#roots[@]}" -ne "''${#ws_names[@]}" ]; then
        echo "ocws: cannot resolve workspace roots" >&2
        return 1
      fi
      # The three key components move exactly when a jj-derived state can
      # change. The repo id is the path jj keeps repo-scoped config under,
      # which every workspace of the repository shares (the workspace root is
      # not shared, so hashing it would fragment the cache per workspace).
      main_cid="$(<"$tmp/main")"
      if [ -z "$main_cid" ]; then
        echo "ocws ls: main@origin not found; run 'jj git fetch' first" >&2
        return 1
      fi
      op_id="$(<"$tmp/op")"
      repo_path="$(<"$tmp/repopath")"
      [ -n "$repo_path" ] || repo_path="$root"
      # jj keeps repo-scoped config under a directory named after the
      # repository, shared by every workspace of it; that name is the cache
      # identity (a workspace root is not shared).
      repo_id=""
      case "$repo_path" in
        */config.toml)
          repo_id="''${repo_path%/config.toml}"
          repo_id="''${repo_id##*/}"
          ;;
      esac
      [ -n "$repo_id" ] || repo_id="$(printf '%s' "$root" | sha256sum | cut -c1-16)"
      board_cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/ocws"
      board_cache_file="$board_cache_dir/board-$repo_id"
      board_lock_file="$board_cache_dir/board-$repo_id.lock"
      key="$(
        {
          printf 'op %s\nmain %s\n' "$op_id" "$main_cid"
          for i in "''${!ws_names[@]}"; do
            printf 'ws %s\t%s\t%s\n' "''${ws_names[$i]}" "''${roots[$i]}" "''${targets[$i]}"
          done
        } | sha256sum
      )"
      key="''${key%% *}"

      # The process snapshot is filtered to the workspace parents by find
      # itself: a readlink pass over /proc is cheap, but handing the board
      # hundreds of unrelated cwds to attribute is not. It overlaps the
      # classification below.
      local -a find_args=()
      local -A find_parents=()
      local parent
      for ws_root in "''${roots[@]}"; do
        parent="''${ws_root%/*}"
        [ -n "''${find_parents[$parent]:-}" ] && continue
        find_parents["$parent"]=1
        if [ "''${#find_args[@]}" -eq 0 ]; then
          find_args=(-lname "$parent/*")
        else
          find_args+=(-o -lname "$parent/*")
        fi
      done
      (
        if [ "''${#find_args[@]}" -eq 0 ]; then
          find /proc/[0-9]*/cwd -maxdepth 0 -printf '%p\t%l\n'
        else
          find /proc/[0-9]*/cwd -maxdepth 0 \( "''${find_args[@]}" \) -printf '%p\t%l\n'
        fi >"$tmp/proc" 2>/dev/null || true
      ) &

      board_states=()
      hit=0
      if [ "$refresh" = 0 ] && [ -n "$op_id" ] && board_cache_load "$key"; then
        hit=1
      fi
      if [ "$hit" = 0 ]; then
        if [ -n "$op_id" ] && board_lock; then
          if [ "$refresh" = 0 ] && board_cache_load "$key"; then
            hit=1
          fi
          if [ "$hit" = 0 ]; then
            if ! board_classify "$tmp"; then
              board_unlock
              return 1
            fi
            if [ "$classify_ok" = 1 ]; then
              board_cache_store "$key"
            fi
          fi
          board_unlock
        else
          board_classify "$tmp" || return 1
        fi
      fi
      wait
      board_roots=()
      for ws_root in "''${roots[@]}"; do
        board_roots["$ws_root"]=1
      done
      proc_load <"$tmp/proc"
      session_load <"$tmp/sessions"

      for i in "''${!ws_names[@]}"; do
        name="''${ws_names[$i]}"
        state="''${board_states[$name]:-}"
        if [ -z "$state" ]; then
          echo "ocws: no classification for workspace '$name'" >&2
          return 1
        fi
        desc="''${descs[$i]}"
        ws_root="''${roots[$i]}"
        live="-"
        ws_live "$ws_root" && live="live"
        if [ "$live" = "-" ] && { [ "$state" = "empty" ] || [ "$state" = "merged" ]; } && ws_session_recent "$ws_root"; then
          live="session"
        fi

        # Parked: an explicit wait marker overrides the commit state for the
        # display and shields the workspace from gc entirely - the marker
        # outclasses the age gate and the liveness scan below.
        wait_parked=0
        wait_created=0
        wait_reason=""
        printf -v marker '%s/%s.wait' "$base" "$name"
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
            [ "$wait_days" -ge "$stale_days" ] && n_waitold=$((n_waitold + 1))
          fi
          # Stale: gc would reclaim it now if not for the age gate - i.e. it
          # is empty/merged and nothing is rooted in it. Live sessions, waiting
          # parkers and young workspaces are excluded so the badge does not nag.
          if [ "$live" = "-" ] && [ "$wait_parked" = 0 ] && { [ "$state" = "empty" ] || [ "$state" = "merged" ]; }; then
            n_stale=$((n_stale + 1))
          fi
          if [ "$wait_parked" = 1 ]; then
            printf -v row '  %-16s %s' "$name" "$desc_display"
            rows_parked+=("$row")
          else
            case "$state" in
              unpushed)
                printf -v row '  %-16s %s' "$name" "$desc_display"
                rows_progress+=("$row")
                ;;
              in-flight)
                printf -v row '  %-16s %s' "$name" "$desc_display"
                rows_review+=("$row")
                ;;
              conflict)
                printf -v row '  %-16s %s' "$name" "$desc_display"
                rows_conflict+=("$row")
                ;;
              empty | merged)
                printf -v row '  %-16s %s' "$name" "$desc_display"
                if [ "$live" != "-" ]; then
                  rows_claimed+=("$row")
                else
                  rows_reclaim+=("$row")
                fi
                ;;
            esac
          fi
        fi
        printf -v row '  %-18s %-10s %-8s %s' "$name" "$state_display" "$live" "$desc_display"
        rows+=("$row")
      done

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
    # A workspace inherits the tracked .envrc, but direnv has never approved
    # the new path: an interactive shell prints a block error on every prompt
    # and never enters the dev shell. Approve only content that still matches
    # main@origin, so an agent-edited .envrc keeps the normal direnv prompt.
    approve_envrc() {
      local dir="$1"
      [ -f "$dir/.envrc" ] || return 0
      (cd "$dir" && jj --ignore-working-copy file show -r main@origin .envrc 2>/dev/null) \
        | cmp -s - "$dir/.envrc" || return 0
      "${direnv}/bin/direnv" allow "$dir" >/dev/null 2>&1 || true
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
      local do_fetch="$1" name dir state desc out age_limit now
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

        # A classification that cannot be read keeps the workspace: this loop
        # removes directories, so "unknown" must never mean "empty".
        if ! out="$(ws_state "$name")"; then
          echo "ocws gc: cannot classify '$name'; keeping it" >&2
          continue
        fi
        IFS=$'\t' read -r state desc <<<"$out"
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
      seat)
        shift
        json=0
        if [ "''${1:-}" = "--json" ]; then
          json=1
          shift
        fi
        [ "$#" -eq 0 ] || usage
        # The shell tool runs in the shared opencode server, not in the pane's
        # client, so its HERDR_* environment can be absent or belong to another
        # pane. The opencode session id is the one identity every tool call
        # carries, and herdr's agent list reports it back with the pane, tab and
        # workspace, so it is the lookup key. A workspace-root match would be
        # wrong here: the live herd reports the same repository cwd for every
        # seat, because `ocws herdr` changes directory inside the pane's shell.
        sid="''${OPENCODE_SESSION_ID:-}"
        if [ -z "$sid" ]; then
          echo "ocws seat: OPENCODE_SESSION_ID is unset; run this from an opencode tool call" >&2
          exit 1
        fi
        herdr_bin="''${HERDR_BIN_PATH:-herdr}"
        command -v "$herdr_bin" >/dev/null 2>&1 || {
          echo "ocws seat: herdr binary not found: $herdr_bin" >&2
          exit 1
        }
        agents="$("$herdr_bin" agent list 2>&1)" || {
          echo "ocws seat: cannot read herdr agents: $agents" >&2
          exit 1
        }
        match="$(printf '%s' "$agents" | jq -c --arg sid "$sid" '
          [.result.agents[]? | select(.agent_session.value == $sid)]
          | if length == 1 then .[0] else empty end
        ' 2>/dev/null || true)"
        if [ -z "$match" ]; then
          count="$(printf '%s' "$agents" | jq -r --arg sid "$sid" \
            '[.result.agents[]? | select(.agent_session.value == $sid)] | length' 2>/dev/null || true)"
          if ! printf '%s' "$count" | grep -Eq '^[0-9]+$'; then
            count=0
          fi
          if [ "$count" -gt 1 ]; then
            echo "ocws seat: session $sid is registered on more than one herdr pane; refusing to guess" >&2
            printf '%s' "$agents" | jq -r --arg sid "$sid" \
              '.result.agents[] | select(.agent_session.value == $sid) | "  \(.pane_id) \(.tab_id) \(.workspace_id) \(.agent_status)"' >&2 || true
          else
            echo "ocws seat: no herdr agent reports opencode session $sid" >&2
            echo "ocws seat: check that tui.herdr.opencodeIntegration is on and the tab is a herdr pane" >&2
          fi
          exit 1
        fi
        here="$(realpath -m "$PWD")"
        names="$(jj --ignore-working-copy workspace list -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null)"
        task=""
        while IFS=$'\t' read -r name ws_root; do
          case "$here/" in
            "$(realpath -m "$ws_root")/"*)
              task="$name"
              dir="$(realpath -m "$ws_root")"
              break
              ;;
          esac
        done <<<"$names"
        [ -n "$task" ] || { echo "ocws seat: not inside a registered jj workspace" >&2; exit 1; }
        [ "$task" = "default" ] && { echo "ocws seat: the primary checkout is not a seat" >&2; exit 1; }
        ws="$(printf '%s' "$match" | jq -r '.workspace_id // empty')"
        tab="$(printf '%s' "$match" | jq -r '.tab_id // empty')"
        pane="$(printf '%s' "$match" | jq -r '.pane_id // empty')"
        state="$(printf '%s' "$match" | jq -r '.agent_status // empty')"
        if [ "$json" = 1 ]; then
          jq -nc \
            --arg task "$task" \
            --arg dir "$dir" \
            --arg ws "$ws" \
            --arg tab "$tab" \
            --arg pane "$pane" \
            --arg sid "$sid" \
            --arg state "$state" \
            '{task:$task,dir:$dir,herdr_workspace:$ws,herdr_tab:$tab,herdr_pane:$pane,agent_session:$sid,agent_status:$state,source:"agent-session"}'
        else
          printf '%s\t%s\t%s\t%s\n' "$task" "$tab" "$pane" "$state"
        fi
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
        # A manual `ocws title` can run from another tab whose shell happens to
        # be cd'ed into the workspace; relabelling that tab would be wrong. The
        # seat's own tab is the one whose foreground process runs in the
        # workspace, so check that before renaming.
        if [ -n "''${HERDR_TAB_ID:-}" ] && command -v herdr >/dev/null 2>&1; then
          tab_cwd="$(herdr pane list 2>/dev/null | jq -r --arg tab "$HERDR_TAB_ID" \
            'first(.result.panes[]? | select(.tab_id == $tab) | (.foreground_cwd // .cwd)) // empty' 2>/dev/null)"
          case "$(realpath -m "''${tab_cwd:-/nonexistent}")/" in
            "$here/"*) herdr tab rename "$HERDR_TAB_ID" "$final" >/dev/null 2>&1 || true ;;
          esac
        fi
        echo "ocws: claimed '$task' as '$final'"
        exit 0
        ;;
      ls|list)
        shift
        counts=0
        board=0
        refresh=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --counts)
              counts=1
              shift
              ;;
            --board)
              board=1
              shift
              ;;
            --refresh)
              refresh=1
              shift
              ;;
            *) usage ;;
          esac
        done
        if [ "$counts" = 0 ] && [ "$board" = 0 ]; then
          jj --ignore-working-copy workspace list
          echo ""
        fi
        if [ "$counts" = 1 ]; then emit_ls counts "$refresh"; elif [ "$board" = 1 ]; then emit_ls board "$refresh"; else emit_ls table "$refresh"; fi
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
        json=0
        focus=1
        workspace=""
        wait_secs=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --json) json=1; shift ;;
            --no-focus) focus=0; shift ;;
            --workspace)
              [ "$#" -ge 2 ] || usage
              workspace="$2"
              shift 2
              ;;
            --wait) wait_secs=180; shift ;;
            --wait=*) wait_secs="''${1#--wait=}"; shift ;;
            --) shift; break ;;
            -*) usage ;;
            *) break ;;
          esac
        done
        case "$wait_secs" in
          *[!0-9]*) usage ;;
        esac
        [ -n "$wait_secs" ] || usage
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

        # Start the tab in the primary workspace, not the caller's workspace:
        # the primary's direnv profile is cached, so the seat does not pay a
        # first-load nix develop before the agent starts. The agent still runs
        # only in the workspace ocws creates (or the existing one it cd's to).
        tab_root="$root"
        if workspace_exists default; then
          tab_root="$(realpath -m "$(ws_root_for default)")"
        fi
        [ -d "$tab_root" ] || tab_root="$root"
        approve_envrc "$tab_root"

        if workspace_exists "$task"; then
          dir="$(realpath -m "$(ws_root_for "$task")")"
          approve_envrc "$dir"
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
          dir="$(ws_dir_for "$task")"
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

        # The tab starts at the primary workspace root: ocws resolves the
        # repository with `jj workspace root`, and the workspace base is
        # outside it. The agent still starts only in the workspace ocws
        # creates (or the existing one it cd's to); nothing runs in the tab's
        # initial directory.
        focus_flag=--focus
        [ "$focus" = 1 ] || focus_flag=--no-focus
        tab_args=(tab create --cwd "$tab_root" --label "$task" "$focus_flag")
        if [ -n "$workspace" ]; then
          tab_args+=(--workspace "$workspace")
        fi
        if ! resp="$("$herdr_bin" "''${tab_args[@]}" 2>&1)"; then
          fail "cannot create a herdr tab: $resp"
        fi
        pane="$(printf '%s' "$resp" | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null || true)"
        tab="$(printf '%s' "$resp" | jq -r '.result.tab.tab_id // empty' 2>/dev/null || true)"
        ws="$(printf '%s' "$resp" | jq -r '.result.tab.workspace_id // empty' 2>/dev/null || true)"
        [ -n "$pane" ] || fail "herdr did not return a root pane: $resp"
        [ -n "$tab" ] || fail "herdr did not return a tab: $resp"
        [ -n "$ws" ] || ws="$workspace"
        if ! "$herdr_bin" pane run "$pane" "$inner"; then
          fail "tab created, but the agent did not start; run 'ocws $task' in it"
        fi
        # herdr has no wait for an agent to appear: agent wait and agent prompt
        # take a target that must already resolve. The pane is the target and
        # agent list is the observable state, so poll it with a deadline rather
        # than handing a lead a pane that cannot be prompted yet. A blocked
        # startup belongs to the person; the tab is kept for inspection.
        state=""
        agent_sid=""
        if [ "$wait_secs" -gt 0 ]; then
          deadline=$(( $(date +%s) + wait_secs ))
          while :; do
            info="$("$herdr_bin" agent list 2>/dev/null || true)"
            state="$(printf '%s' "$info" | jq -r --arg p "$pane" 'first(.result.agents[]? | select(.pane_id == $p) | .agent_status) // empty' 2>/dev/null || true)"
            agent_sid="$(printf '%s' "$info" | jq -r --arg p "$pane" 'first(.result.agents[]? | select(.pane_id == $p) | .agent_session.value) // empty' 2>/dev/null || true)"
            case "$state" in
              idle|done) break ;;
              blocked)
                fail "tab $tab pane $pane is blocked; read it with 'herdr agent read $pane --source recent-unwrapped' and let the person answer"
                ;;
            esac
            if [ "$(date +%s)" -ge "$deadline" ]; then
              fail "tab $tab pane $pane did not reach an agent prompt in ''${wait_secs}s; inspect it before prompting"
            fi
            sleep 0.5
          done
        fi
        if [ "$json" = 1 ]; then
          jq -nc \
            --arg task "$task" \
            --arg dir "$(realpath -m "$dir")" \
            --arg label "$task" \
            --arg ws "$ws" \
            --arg tab "$tab" \
            --arg pane "$pane" \
            --arg state "$state" \
            --arg sid "$agent_sid" \
            '{task:$task,dir:$dir,label:$label,herdr_workspace:$ws,herdr_tab:$tab,herdr_pane:$pane,agent_status:$state,agent_session:$sid}'
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
    approve_envrc "$dir"

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
