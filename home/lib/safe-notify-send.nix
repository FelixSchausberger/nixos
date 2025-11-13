{
  pkgs,
  config,
  ...
}: let
  claudeNotifier = "${config.home.homeDirectory}/.local/share/claude-wsl/send-notification.ps1";
  script =
    builtins.replaceStrings
    ["@LIBNOTIFY@" "@CLAUDE_NOTIFY@"]
    ["${pkgs.libnotify}/bin/notify-send" claudeNotifier]
    (builtins.readFile ./safe-notify-send.sh);
in
  pkgs.writeShellScriptBin "safe-notify-send" script
