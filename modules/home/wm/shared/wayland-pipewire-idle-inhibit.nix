# Shared wayland-pipewire-idle-inhibit configuration
# This prevents conflicts when multiple WM modules are imported
{
  lib,
  config,
  ...
}: let
  niriEnabled = config.wm.niri.enable or false;
  hyprlandEnabled = config.wm.hyprland.enable or false;

  # Determine the systemd target based on which WM is enabled
  systemdTarget =
    if niriEnabled
    then "niri-session.target"
    else if hyprlandEnabled
    then "hyprland-session.target"
    else "graphical-session.target"; # fallback

  # Only enable if at least one WM is enabled
  shouldEnable = niriEnabled || hyprlandEnabled;
in {
  config = lib.mkIf shouldEnable {
    services.wayland-pipewire-idle-inhibit = {
      enable = true;
      inherit systemdTarget;
      settings = {
        verbosity = "INFO";
        media_minimum_duration = 5;
        idle_inhibitor = "wayland";
        sink_whitelist = [];
        node_blacklist = [
          {name = "spotify";}
          {app_name = "Music Player Daemon";}
        ];
      };
    };
  };
}
