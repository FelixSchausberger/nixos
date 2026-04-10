# Hyprland UWSM registration
#
# Registers Hyprland with UWSM to create proper desktop entries
# that tuigreet/greetd can discover for session selection.
{
  lib,
  pkgs,
  hostConfig,
  inputs,
  ...
}: let
  hasHyprland = builtins.elem "hyprland" (hostConfig.wms or []);
  hyprlandPkg = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
in {
  config = lib.mkIf hasHyprland {
    programs.uwsm.waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment = "Hyprland tiling Wayland compositor";
      binPath = "${hyprlandPkg}/bin/Hyprland";
    };
  };
}
