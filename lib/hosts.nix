# hostConfig is the single source of truth for per-host behaviour.
# Modules guard themselves with lib.mkIf to avoid evaluating inactive features.
# wms controls which window manager modules activate; isGui skips the entire
# GUI stack on TUI-only hosts.
{
  desktop = {
    wms = ["niri"]; # Default WM; COSMIC/Hyprland available via specialisation
    isGui = true;
    description = "Desktop with Hyprland as default WM for headless Sunshine streaming";
    ip = "192.168.178.3";
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
    wms = [];
    isGui = false;
    isWsl = true; # WSL2 environment — disables greetd and bare-metal features
    description = "WSL2 headless environment (TUI-only)";
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
    ip = "192.168.178.2";
  };
}
