{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkIf config.features.productivity.enable (with pkgs; [
    basalt # TUI Application to manage Obsidian notes directly from the terminal
    obsidian
  ]);
}
