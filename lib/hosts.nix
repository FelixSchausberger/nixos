# hostConfig is the single source of truth for per-host behaviour.
# Modules guard themselves with lib.mkIf to avoid evaluating inactive features.
# wms controls which window manager modules activate; isGui skips the entire
# GUI stack on TUI-only hosts; guiApps selects the desktop application set (a
# managed desktop: isGui with an auto-started session).
# tailnetIp is the Tailscale-assigned address, stable per node; the phone reads
# it to resolve fleet names while it runs with Tailscale DNS disabled.
{
  desktop = {
    wms = ["niri"]; # Default WM (the cosmic module stays available in hosts/lib.nix)
    isGui = true;
    description = "Desktop workstation/gaming host with Niri WM; streams headless via Moonshine";
    ip = "192.168.178.3";
    # MAC pinned in networkd (see hosts/desktop) and used for Wake-on-LAN
    # from hosts/m920q (desktopPower) — change both together via this value.
    lanMac = "10:ff:e0:e1:53:55";
    tailnetIp = "100.102.113.5";
  };

  surface = {
    wms = ["niri"];
    isGui = true;
    description = "Surface tablet with Niri WM";
    ip = "192.168.178.37";
  };

  hp-probook-wsl = {
    wms = [];
    isGui = false;
    isWsl = true; # WSL2 environment — disables greetd and bare-metal features
    description = "WSL2 headless environment (TUI-only)";
    tailnetIp = "100.125.85.126";
  };

  hp-probook-vmware = {
    wms = ["niri"];
    isGui = true;
    description = "VMware VM with Niri on HP ProBook 465 G11";
  };

  m920q = {
    wms = ["niri"];
    isGui = true;
    description = "Lenovo ThinkCentre M920q homelab server (headless base; niri session starts on projector hotplug)";
    ip = "192.168.178.2";
    tailnetIp = "100.105.37.12";
    # Replays Wake-on-LAN to the desktop (hosts/m920q desktopPower).
  };
}
