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
  pkgs,
  hostConfig,
  ...
}: let
  # Compositors managed by UWSM (GNOME has its own session manager)
  uwsmCompositors = ["hyprland" "niri" "cosmic"];

  # Check if any UWSM-managed compositor is enabled
  hasUwsmCompositor = builtins.any (wm: builtins.elem wm (hostConfig.wms or [])) uwsmCompositors;

  # dbus-broker 37 uses Type=notify-reload but dbus-broker-launch does not send
  # RELOADING=1/READY=1 sd_notify messages, causing 90-second timeouts on every
  # nixpkgs update (X-Restart-Triggers hash changes → systemd reloads dbus-broker).
  # This script properly implements the notify-reload protocol.
  dbusReloadScript = pkgs.writeShellScript "dbus-reload" ''
    ${pkgs.systemd}/bin/systemd-notify RELOADING=1
    ${pkgs.systemd}/bin/busctl --system call org.freedesktop.DBus \
      /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig 2>/dev/null || true
    ${pkgs.systemd}/bin/systemd-notify READY=1
  '';
in {
  config = lib.mkIf hasUwsmCompositor {
    programs.uwsm.enable = true;

    # dbus-broker recommended for UWSM compatibility
    # It reuses systemd activation environment, simplifying cleanup
    services.dbus.implementation = lib.mkDefault "broker";

    systemd.services.dbus.serviceConfig = {
      # Required so the ExecReload subprocess can send sd_notify messages
      NotifyAccess = lib.mkForce "all";
      ExecReload = lib.mkForce "${dbusReloadScript}";
    };
  };
}
