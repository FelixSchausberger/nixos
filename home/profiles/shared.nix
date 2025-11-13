{hostName ? "", ...}: let
  # Map hostname to window managers to avoid circular dependency
  wmForHost = {
    "desktop" = ["hyprland" "niri"];
    "surface" = ["hyprland"];
    "portable" = []; # TUI-only emergency/recovery system
    "hp-probook-wsl" = ["niri"]; # WSL with niri WM
  };

  # Use provided hostname
  currentHost = hostName;

  # Get WM modules for current host (default to TUI-only for security/minimalism)
  wms = wmForHost.${currentHost} or [];
  wmModules = map (wm: ../../modules/home/wm + "/${wm}/default.nix") wms;
in {
  imports =
    [
      # Base home configuration
      ../../modules/home
    ]
    ++ wmModules;
}
