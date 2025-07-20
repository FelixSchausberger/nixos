{hostName ? "", ...}: let
  # Map hostname to window managers to avoid circular dependency
  wmForHost = {
    "desktop" = ["hyprland"];
    "surface" = ["hyprland"];
    "pdemu1cml000312" = ["hyprland"];
    "portable" = ["hyprland"];
  };

  # Use provided hostname or default to hyprland
  currentHost = hostName;

  # Get WM modules for current host
  wms = wmForHost.${currentHost} or ["hyprland"];
  wmModules = map (wm: ../../modules/home/wm + "/${wm}/default.nix") wms;
in {
  imports =
    [
      # Base home configuration
      ../../modules/home
    ]
    ++ wmModules;
}
