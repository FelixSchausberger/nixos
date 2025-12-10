# Core UWSM (Universal Wayland Session Manager) configuration
#
# UWSM manages Wayland compositor sessions by:
# - Binding compositors to graphical-session.target
# - Handling environment propagation (WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP)
# - Managing XDG autostart applications
#
# This module auto-enables when any UWSM-managed compositor is configured.
# GNOME uses its own session manager and doesn't need UWSM.
{
  lib,
  hostConfig,
  ...
}: let
  # Compositors managed by UWSM (GNOME has its own session manager)
  uwsmCompositors = ["hyprland" "niri" "cosmic"];

  # Check if any UWSM-managed compositor is enabled
  hasUwsmCompositor = builtins.any (wm: builtins.elem wm (hostConfig.wms or [])) uwsmCompositors;
in {
  config = lib.mkIf hasUwsmCompositor {
    programs.uwsm.enable = true;

    # dbus-broker recommended for UWSM compatibility
    # It reuses systemd activation environment, simplifying cleanup
    services.dbus.implementation = lib.mkDefault "broker";
  };
}
