# Centralized host->WM mapping
# Single source of truth for which window managers run on which hosts
{
  desktop = {
    wms = ["gnome" "hyprland" "niri"];
    isGui = true;
    description = "Desktop PC";
  };

  surface = {
    wms = ["niri"];
    isGui = true;
    description = "Surface Pro 5";
  };

  portable = {
    wms = [];
    isGui = false;
    description = "TUI-only emergency/recovery system";
  };

  hp-probook-wsl = {
    wms = []; # No window manager needed in WSL
    isGui = true; # Keep GUI support for WSLg apps
    description = "WSL environment on HP Probook 465 G11";
  };

  hp-probook-vmware = {
    wms = ["niri"];
    isGui = true;
    description = "VMware VM on HP ProBook 465 G11";
  };
}
