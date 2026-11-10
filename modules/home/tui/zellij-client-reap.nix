# Detaches zellij attach clients left behind by a dead mosh session.
#
# Zellij sizes a tab for its smallest viewer (per-client tab sizes, 0.45+),
# so a client that nobody is watching still counts: the tab is laid out for
# its old pty geometry and the terminal in front of the user is filled only
# partway. A tab opened through the phantom gets the live client's size, which
# makes the clamp look tab-specific.
#
# Mosh outlives its transport by design: closing the laptop, restarting WSL or
# changing networks kills mosh-client without a clean quit, mosh-server keeps
# running, and its `zellij attach` stays registered as a viewer. Detaching the
# phantom is lossless - the session and every pane keep running server-side,
# only the dead client's terminal goes away.
#
# A client is presumed orphaned when it is older than the age bound and
# smaller than the newest client of its session: a bigger client cannot clamp
# the visible tab, and a tab with a single client is never touched because
# that client is its own newest.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.tui.zellijClientReap;

  # Long enough that a second live window at a different size survives a
  # workday, short enough that yesterday's session is gone before the next
  # login.
  maxAgeSeconds = 12 * 60 * 60;

  reaper = pkgs.writeShellApplication {
    name = "zellij-client-reap";
    runtimeInputs = [pkgs.zellij pkgs.procps pkgs.coreutils];
    text = ''
      # Best effort by design: writeShellApplication turns on errexit, and a
      # client exiting in the middle of the scan must not abort the run.
      set +o errexit
      set -o nounset -o pipefail

      max_age=${toString maxAgeSeconds}

      while IFS= read -r line; do
        session="''${line%% *}"
        if [ -z "$session" ]; then
          continue
        fi

        # Attach clients are exactly `<zellij> attach <session>`; the server
        # (`--server`) and the web client (`web --start`) do not match.
        pids=()
        ages=()
        ttys=()
        newest_pid=""
        newest_age=""
        newest_tty=""
        for pid in $(pgrep -x zellij || true); do
          mapfile -t argv < <(tr "\0" "\n" < "/proc/$pid/cmdline") || continue
          if [ "''${#argv[@]}" -ne 3 ] || [ "''${argv[1]}" != "attach" ] || [ "''${argv[2]}" != "$session" ]; then
            continue
          fi
          age="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d "[:space:]")"
          tty="$(ps -o tty= -p "$pid" 2>/dev/null | tr -d "[:space:]")"
          if [ -z "$age" ] || [ -z "$tty" ] || [ "$tty" = "?" ]; then
            continue
          fi
          pids+=("$pid")
          ages+=("$age")
          ttys+=("$tty")
          if [ -z "$newest_age" ] || [ "$age" -lt "$newest_age" ]; then
            newest_pid="$pid"
            newest_age="$age"
            newest_tty="$tty"
          fi
        done

        if [ -z "$newest_pid" ]; then
          continue
        fi
        newest_size="$(stty -F "/dev/$newest_tty" size 2>/dev/null || true)"
        if [ -z "$newest_size" ]; then
          continue
        fi
        read -r newest_rows newest_cols <<<"$newest_size"

        for i in "''${!pids[@]}"; do
          pid="''${pids[$i]}"
          age="''${ages[$i]}"
          tty="''${ttys[$i]}"
          if [ "$pid" = "$newest_pid" ] || [ "$age" -le "$max_age" ]; then
            continue
          fi
          size="$(stty -F "/dev/$tty" size 2>/dev/null || true)"
          if [ -z "$size" ]; then
            continue
          fi
          read -r rows cols <<<"$size"
          if [ "$rows" -ge "$newest_rows" ] && [ "$cols" -ge "$newest_cols" ]; then
            continue
          fi
          kill "$pid" 2>/dev/null || continue
          echo "detached stale client $pid from session '$session' (''${age}s old, ''${cols}x''${rows} vs newest ''${newest_cols}x''${newest_rows})"
        done
      done < <(zellij list-sessions --no-formatting 2>/dev/null || true)
    '';
  };
in {
  options.tui.zellijClientReap = {
    enable =
      lib.mkEnableOption "detaching zellij clients orphaned by a dead mosh session"
      // {
        default = true;
      };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [reaper];

    systemd.user.services.zellij-client-reap = {
      Unit = {
        Description = "Detach zellij clients orphaned by dead mosh sessions";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${reaper}/bin/zellij-client-reap";
      };
    };

    systemd.user.timers.zellij-client-reap = {
      Unit = {
        Description = "Periodically detach orphaned zellij clients";
      };
      Timer = {
        OnBootSec = "3min";
        OnUnitActiveSec = "5min";
        AccuracySec = "30s";
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
