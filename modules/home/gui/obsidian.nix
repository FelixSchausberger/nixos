{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkIf config.features.productivity.enable (with pkgs; [
    obsidian
  ]);
}
