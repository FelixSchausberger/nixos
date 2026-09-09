# Pushes OpenCode Go subscription quota into the zjstatus bar via a zellij
# pipe. Version-independent by design: it only talks to the official Go usage
# API and the zellij CLI, so it survives opencode plugin-API changes (V1/V2).
#
# The poller runs as a systemd user timer (no graphical session needed) and
# exits silently when there is no Go credential or no running zellij session.
# The rendered segment is `{pipe_opencode_quota}` in zellij.nix.
{pkgs, ...}: let
  # Latest observed state persists in zjstatus: on any failure (no key, no
  # session, API error) the bridge exits 0 and the bar keeps the last value.
  quotaBridge = pkgs.writeShellApplication {
    name = "opencode-quota-bridge";
    runtimeInputs = with pkgs; [
      curl
      jq
      zellij
      gnugrep
      coreutils
    ];
    text = ''
      set -euo pipefail

      auth="$HOME/.local/share/opencode/auth.json"
      [ -f "$auth" ] || exit 0
      key="$(jq -r '."opencode-go".key // empty' "$auth")"
      [ -n "$key" ] || exit 0

      usage="$(curl -sf --max-time 8 \
        -H "Authorization: Bearer $key" \
        https://opencode.ai/zen/go/v1/usage)" || exit 0

      payload="$(jq -er '
        .usage
        | "Go 5h \(.rolling.percent // "?")% · wk \(.weekly.percent // "?")% · mo \(.monthly.percent // "?")%"
      ' <<<"$usage")" || exit 0

      # Prefer the auto-attach session; fall back to the first live session.
      session="$(zellij list-sessions --no-formatting 2>/dev/null \
        | grep -v EXITED | head -1 | cut -d' ' -f1)"
      [ -n "$session" ] || exit 0

      zellij --session "$session" pipe \
        "zjstatus::pipe::pipe_opencode_quota::$payload"
    '';
  };
in {
  home.packages = [quotaBridge];

  systemd.user.services.opencode-quota-bridge = {
    Unit = {
      Description = "Push OpenCode Go quota into the zjstatus bar";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${quotaBridge}/bin/opencode-quota-bridge";
      # Network + credential read; failure is non-fatal by script design.
      Restart = "no";
    };
  };

  systemd.user.timers.opencode-quota-bridge = {
    Unit = {
      Description = "Periodically push OpenCode Go quota to zjstatus";
    };
    Timer = {
      OnBootSec = "90s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
