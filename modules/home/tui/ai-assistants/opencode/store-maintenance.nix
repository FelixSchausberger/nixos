# Bounds the OpenCode session store by size, never by the calendar. Session
# history is the one thing in the store that cannot be regenerated, so nothing
# is deleted while the database is under budget, however old it is; age only
# bounds which sessions are eligible once the budget is exceeded.
#
# Ordering is forced by SQLite: deleting rows moves pages to the freelist, so a
# size-triggered prune that never VACUUMs would fire forever without shrinking
# anything. VACUUM needs the database to itself, so the export and delete steps
# run against the live server, the server then stops for the checkpoint and
# vacuum, and starts again. Stopping it drops live sessions, so it is the last
# thing that happens and only after something was actually pruned.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ai-assistants.opencode.store;

  dataDir = "${config.xdg.dataHome}/opencode";
  dbFile = "${dataDir}/opencode.db";

  # The launcher resolves the registered background service, so the CLI reads
  # and mutates through the same server the TUI and the web UI use instead of
  # opening a second one against the database (v2.nix).
  launcher = config.ai-assistants.opencode.package;

  # The unit the CLI attaches to, and the one that must be stopped for VACUUM to
  # own the database. A hard dependency rather than a detail: with the unit
  # down, the CLI's own service resolution would start an unmanaged server that
  # systemctl cannot stop for the vacuum step.
  webUnit = "opencode-web";

  # Shell truthiness for the script below.
  dryRunFlag =
    if cfg.dryRun
    then "1"
    else "0";

  maintenance = pkgs.writeShellApplication {
    name = "opencode-store-maintenance";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      jq
      sqlite
      systemd
    ];
    text = ''
      set -euo pipefail

      dryRun=${dryRunFlag}
      keepDays=${toString cfg.keepDays}
      cacheMaxAgeDays=${toString cfg.cacheMaxAgeDays}
      maxStoreGib=${toString cfg.maxStoreGib}
      archiveDir=${lib.escapeShellArg cfg.archiveDir}
      dataDir=${lib.escapeShellArg dataDir}
      dbFile=${lib.escapeShellArg dbFile}
      cacheDir=${lib.escapeShellArg "${config.xdg.cacheHome}/opencode"}
      launcher=${lib.escapeShellArg "${launcher}/bin/opencode"}
      webUnit=${lib.escapeShellArg webUnit}
      sqlite=${pkgs.sqlite}/bin/sqlite3

      log() { printf '%s\n' "$*"; }
      human() { numfmt --to=iec --suffix=B "$1"; }
      tab="$(printf '\t')"

      log "opencode store maintenance: dryRun=$dryRun keepDays=$keepDays cacheMaxAgeDays=$cacheMaxAgeDays maxStoreGib=$maxStoreGib"

      # Age-based pruning of data that is regenerated on demand. Deletion here
      # is real, deliberately: the rip graveyard the agent shells write to would
      # keep every pruned byte on disk, which is the opposite of the point.
      prune_derived() {
        local dir="$1" days="$2" label="$3" count bytes
        if [ ! -d "$dir" ]; then
          log "$label: absent"
          return 0
        fi
        count="$(find "$dir" -mindepth 1 -type f -mtime "+$days" 2>/dev/null | wc -l)"
        if [ "$count" -eq 0 ]; then
          log "$label: nothing older than ''${days}d"
          return 0
        fi
        bytes="$(find "$dir" -mindepth 1 -type f -mtime "+$days" -printf '%s\n' 2>/dev/null | awk '{s += $1} END {print s + 0}')"
        log "$label: $count file(s), $(human "$bytes") older than ''${days}d"
        if [ "$dryRun" -eq 1 ]; then
          return 0
        fi
        find "$dir" -mindepth 1 -type f -mtime "+$days" -delete 2>/dev/null || true
        # Emptied directories are what the file deletion above leaves behind.
        find "$dir" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
      }

      prune_derived "$cacheDir" "$cacheMaxAgeDays" "cache"
      prune_derived "$dataDir/log" "$cacheMaxAgeDays" "log"
      # Session-coupled, so it ages out on the session horizon rather than the
      # cache horizon: tool output is referenced by messages.
      prune_derived "$dataDir/tool-output" "$keepDays" "tool-output"
      # $dataDir/snapshot is deliberately not pruned here: each entry is a
      # per-project git repository, so an age cap would have to drop whole
      # repositories rather than files, and that deserves its own change.

      if [ ! -e "$dbFile" ]; then
        log "store: $dbFile absent, skipping the size step"
        exit 0
      fi

      budget=$((maxStoreGib * 1073741824))

      # Apparent size, not allocated: the store lives on ZFS, where compression
      # makes the block count an unreliable measure of how much the database
      # holds. The write-ahead log is included because it is part of the file
      # the store occupies until the next checkpoint.
      store_bytes() {
        local total=0 f
        for f in "$dbFile" "$dbFile-wal"; do
          [ -e "$f" ] || continue
          total=$((total + $(du -sb "$f" | cut -f1)))
        done
        printf '%s' "$total"
      }

      # One row per top-level session, oldest activity first. Reads are
      # schema-coupled by design: `session list` is scoped to the current
      # project, and this store spans dozens of project directories, so it
      # cannot enumerate the candidates. Every mutation goes through the CLI.
      #
      # The per-tree byte figure is the raw message payload, a lower bound on
      # what deleting the tree frees (index and page overhead are excluded), so
      # the selection below under-reaches and the re-measure loop converges
      # from below instead of deleting more history than the budget needs.
      tree_summary() {
        "$sqlite" -readonly -noheader -separator "$tab" "$dbFile" "
          WITH RECURSIVE tree(root, id) AS (
            SELECT id, id FROM session_v2 WHERE parent_id IS NULL
            UNION ALL
            SELECT t.root, c.id FROM session_v2 c JOIN tree t ON c.parent_id = t.id
          )
          SELECT t.root,
                 MAX(COALESCE(m.last_active, s.time_updated)) AS last_active,
                 COALESCE(SUM(COALESCE(m.bytes, 0)), 0) AS bytes,
                 COUNT(*) AS sessions
          FROM tree t
          JOIN session_v2 s ON s.id = t.id
          LEFT JOIN (
            SELECT session_id,
                   MAX(time_updated) AS last_active,
                   SUM(LENGTH(CAST(data AS BLOB))) AS bytes
            FROM session_message
            GROUP BY session_id
          ) m ON m.session_id = t.id
          GROUP BY t.root
          HAVING MAX(COALESCE(m.last_active, s.time_updated)) < $1
          ORDER BY last_active ASC;"
      }

      # A session tree: the root plus every descendant. `session export` covers
      # one session and `session delete` removes the whole tree, so the members
      # are enumerated here to export them all before the delete cascades.
      tree_members() {
        "$sqlite" -readonly -noheader -separator "$tab" "$dbFile" "
          WITH RECURSIVE tree(id) AS (
            SELECT '$1'
            UNION ALL
            SELECT c.id FROM session_v2 c JOIN tree t ON c.parent_id = t.id
          )
          SELECT t.id, COALESCE(s.slug, 'session')
          FROM tree t JOIN session_v2 s ON s.id = t.id;"
      }

      size="$(store_bytes)"
      log "store: $(human "$size") of $(human "$budget") budget"
      if [ "$size" -le "$budget" ]; then
        log "store: under budget, nothing to do"
        exit 0
      fi

      stopped=0
      restore_service() {
        if [ "$stopped" -eq 1 ]; then
          log "restarting $webUnit"
          systemctl --user start "$webUnit" || true
          stopped=0
        fi
      }
      trap restore_service EXIT

      attempt=1
      while [ "$size" -gt "$budget" ] && [ "$attempt" -le 5 ]; do
        cutoff=$((($(date +%s) - keepDays * 86400) * 1000))
        excess=$((size - budget))
        log "prune round $attempt: need at least $(human "$excess") reclaimed"

        summary="$(tree_summary "$cutoff")"
        mapfile -t summary_lines <<< "$summary"
        plan_lines=()
        freed=0
        for line in "''${summary_lines[@]}"; do
          [ -n "$line" ] || continue
          plan_lines+=("$line")
          IFS="$tab" read -r _ _ bytes _ <<< "$line"
          freed=$((freed + bytes))
          if [ "$freed" -ge "$excess" ]; then
            break
          fi
        done
        planned="''${#plan_lines[@]}"

        if [ "$planned" -eq 0 ]; then
          log "prune: no session older than ''${keepDays}d; the budget cannot be met without deleting younger history, stopping"
          break
        fi

        log "prune: $planned oldest session tree(s), $(human "$freed") of message data"
        if [ "$dryRun" -eq 1 ]; then
          for line in "''${plan_lines[@]}"; do
            IFS="$tab" read -r root last_active bytes sessions <<< "$line"
            printf '  %s  last active %s  %s  %s session(s)\n' \
              "$root" "$(date -d "@$((last_active / 1000))" +%Y-%m-%d)" "$(human "$bytes")" "$sessions"
          done
          log "prune: dry run, nothing exported or deleted"
          break
        fi

        mkdir -p "$archiveDir"
        # Bring the unit up before the CLI runs: its own service resolution
        # would otherwise start a server this script cannot stop for VACUUM.
        systemctl --user start "$webUnit" >/dev/null 2>&1 || true

        pruned=0
        for line in "''${plan_lines[@]}"; do
          IFS="$tab" read -r root _ _ _ <<< "$line"
          if ! [[ "$root" =~ ^ses_[A-Za-z0-9]+$ ]]; then
            log "prune: refusing unexpected session id '$root'"
            continue
          fi
          export_ok=1
          while IFS="$tab" read -r member slug; do
            [ -n "$member" ] || continue
            tmp="$(mktemp "$archiveDir/.export.XXXXXX")"
            # Export first, always: a session is never deleted without a
            # readable export on disk, and one failed member abandons the whole
            # tree rather than leaving the delete to cascade over it.
            if ! "$launcher" session export "$member" >"$tmp" 2>/dev/null || ! jq -e . "$tmp" >/dev/null 2>&1; then
              log "prune: export of $member failed, skipping its tree ($root)"
              rm -f "$tmp"
              export_ok=0
              break
            fi
            mv "$tmp" "$archiveDir/$member-$slug.json"
          done < <(tree_members "$root")
          if [ "$export_ok" -ne 1 ]; then
            continue
          fi
          if "$launcher" session delete "$root" >/dev/null 2>&1; then
            log "prune: exported and deleted $root"
            pruned=$((pruned + 1))
          else
            log "prune: delete of $root failed; its export is archived and the next run retries"
          fi
        done

        if [ "$pruned" -eq 0 ]; then
          log "prune: nothing was deleted, stopping"
          break
        fi

        systemctl --user stop "$webUnit" || true
        stopped=1
        if ! "$sqlite" -cmd ".timeout 60000" "$dbFile" "PRAGMA wal_checkpoint(TRUNCATE); VACUUM;" >/dev/null; then
          log "prune: checkpoint/vacuum failed"
        fi
        restore_service

        new_size="$(store_bytes)"
        log "prune: store is now $(human "$new_size")"
        if [ "$new_size" -ge "$size" ]; then
          log "prune: the store did not shrink; stopping rather than deleting more history"
          size="$new_size"
          break
        fi
        size="$new_size"
        attempt=$((attempt + 1))
      done

      if [ "$size" -gt "$budget" ]; then
        log "store: still $(human "$size") against a $(human "$budget") budget"
      fi
    '';
  };
in {
  options.ai-assistants.opencode.store = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Weekly maintenance for the OpenCode session store: age-cap the derived
        data, and once the database exceeds maxStoreGib, export the oldest
        eligible session trees and delete them.
      '';
    };

    maxStoreGib = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = ''
        Size ceiling in GiB for the session database (apparent bytes, including
        the write-ahead log). This is the only trigger: while the database is
        under budget nothing is deleted, however old it is.
      '';
    };

    keepDays = lib.mkOption {
      type = lib.types.int;
      default = 180;
      description = ''
        Age a session must exceed before it becomes a prune candidate. Age
        bounds the candidates only; it never triggers a deletion on its own.
        Applies to tool-output pruning as well.
      '';
    };

    cacheMaxAgeDays = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = ''
        Days a cache or log file survives. These are regenerated on demand, so
        they age out independently of the session horizon.
      '';
    };

    archiveDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/opencode/archive/pruned";
      description = ''
        Directory holding the JSON export of every pruned session. An export is
        written and verified before its session is deleted, so this is the only
        copy once the prune completes.
      '';
    };

    dryRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Report what would be pruned without exporting, deleting or vacuuming
        anything. Kept on by default so the destructive path is opted into
        deliberately.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Weekly, not nightly: size is the trigger, so a nightly run would only
    # re-measure. The slot is a daytime one on purpose - the always-on host
    # keeps its disks quiet between 00:00 and 09:00.
    systemd.user.services.opencode-store-maintenance = {
      Unit.Description = "Bound the OpenCode session store by size (export, then prune)";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe maintenance;
      };
    };

    systemd.user.timers.opencode-store-maintenance = {
      Install.WantedBy = ["timers.target"];
      Timer = {
        OnCalendar = "Sun 15:00:00";
        Persistent = true;
        # Spreads the fleet's hosts, which share the schedule.
        RandomizedDelaySec = "15m";
      };
    };
  };
}
