{pkgs, ...}: let
  script =
    builtins.replaceStrings
    ["@LIBNOTIFY@" "@CLAUDE_NOTIFY@"]
    ["${pkgs.libnotify}/bin/notify-send" ""]
    (builtins.readFile ./safe-notify-send.sh);
in
  pkgs.writeShellScriptBin "safe-notify-send" script
