# hostConfig is the single source of truth for per-host behaviour.
# Modules guard themselves with lib.mkIf to avoid evaluating inactive features.
# wms controls which window manager modules activate; isGui skips the entire
# GUI stack on TUI-only hosts.
{
  desktop = {
    wms = ["hyprland"]; # Default WM, others via specialisations
    isGui = true;
    description = "Desktop with switchable WMs via specialisations";
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

  hp-probook-vmware = {
    wms = ["niri"];
    isGui = true;
    description = "VMware VM with Niri on HP ProBook 465 G11";
  };

  m920q = {
    wms = [];
    isGui = false;
    description = "Lenovo ThinkCentre M920q homelab server (headless, niri-gui specialisation available)";
  };
}
