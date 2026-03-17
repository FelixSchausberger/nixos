# Cosmic UWSM registration
#
# Registers Cosmic with UWSM for consistent session management.
# While Cosmic has its own session manager (cosmic-session),
# wrapping it with UWSM provides unified graphical-session.target
# activation and consistent display manager integration.
{
  lib,
  pkgs,
  hostConfig,
  ...
}: let
  hasCosmic = builtins.elem "cosmic" (hostConfig.wms or []);
in {
  config = lib.mkIf hasCosmic {
    programs.uwsm.waylandCompositors.cosmic = {
      prettyName = "COSMIC";
      comment = "COSMIC Desktop Environment";
      binPath = "${pkgs.cosmic-session}/bin/cosmic-session";
    };
  };
}
