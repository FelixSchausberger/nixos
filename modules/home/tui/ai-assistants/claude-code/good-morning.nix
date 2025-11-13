# Claude Code Good Morning Message
#
# Sends a scheduled good morning message to Claude Code using systemd user timers.
#
# Key features:
# - Runs at configured time daily (default: 7am)
# - Uses Persistent=true to ensure delivery even if PC was off at scheduled time
# - Configurable message content
#
# Usage in home profile:
#   programs.claude-code.goodMorning = {
#     enable = true;
#     time = "07:00:00";
#     message = "Good morning! Ready to start the day.";
#   };
#
# Managing the timer:
#   systemctl --user status claude-code-good-morning.timer
#   systemctl --user list-timers claude-code-good-morning.timer
#   journalctl --user -u claude-code-good-morning.service
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.claude-code.goodMorning;
in {
  options.programs.claude-code.goodMorning = {
    enable = lib.mkEnableOption "daily good morning message for Claude Code";

    time = lib.mkOption {
      type = lib.types.str;
      default = "07:00:00";
      description = "Time to send the good morning message (HH:MM:SS format)";
    };

    message = lib.mkOption {
      type = lib.types.str;
      default = "Good morning! Ready to start the day.";
      description = "Message to send to Claude Code";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.claude-code-good-morning = {
      Unit = {
        Description = "Claude Code good morning message";
      };

      Service = {
        Type = "oneshot";
        ExecStart = let
          sendMessageScript = pkgs.writeShellScript "claude-good-morning" ''
            set -euo pipefail

            # Check if claude-code is available
            if ! command -v claude &> /dev/null; then
              echo "Error: claude command not found" >&2
              exit 1
            fi

            # Send the message to Claude Code
            ${pkgs.claude-code}/bin/claude -p '${cfg.message}'
          '';
        in
          toString sendMessageScript;
      };
    };

    systemd.user.timers.claude-code-good-morning = {
      Unit = {
        Description = "Timer for Claude Code good morning message";
      };

      Timer = {
        OnCalendar = "*-*-* ${cfg.time}";
        Persistent = true; # Run on next login if machine was off at scheduled time
        Unit = "claude-code-good-morning.service";
      };

      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
