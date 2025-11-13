# Centralized host->WM mapping
# Single source of truth for which window managers run on which hosts
{
  desktop = {
    wms = ["gnome" "hyprland" "niri"];
    isGui = true;
    description = "Full desktop with multiple WMs";
  };

  surface = {
    wms = ["niri"];
    isGui = true;
    description = "Surface tablet with Niri WM";
  };

  portable = {
    wms = [];
    isGui = false;
    description = "TUI-only emergency/recovery system";
  };

  hp-probook-wsl = {
    wms = ["niri"]; # WSL with niri WM support via WSLg
    isGui = true; # Enable GUI support for WSLg
    description = "WSL environment with Niri WM";
  };
}
