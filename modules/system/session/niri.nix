# Niri UWSM registration
#
# Registers Niri with UWSM to create proper desktop entries
# that tuigreet/greetd can discover for session selection.
{
  lib,
  pkgs,
  hostConfig,
  inputs,
  ...
}: let
  hasNiri = builtins.elem "niri" (hostConfig.wms or []);
  niriPkg = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
in {
  config = lib.mkIf hasNiri {
    programs.uwsm.waylandCompositors.niri = {
      prettyName = "Niri";
      comment = "Scrollable tiling Wayland compositor";
      # --session flag exports WAYLAND_DISPLAY to systemd activation environment,
      # which UWSM needs for automatic finalization
      binPath = "${niriPkg}/bin/niri --session";
    };
  };
}
