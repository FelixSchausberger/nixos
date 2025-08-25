let
  hostLib = import ../lib.nix;
  wms = ["hyprland" "gnome"];
in {
  imports =
    [
      ../shared.nix
      ./hardware-configuration.nix
      ../../modules/system/work
      ../../system/nix/work/substituters.nix
    ]
    ++ hostLib.wmModules wms;

  hostConfig = {
    hostName = "pdemu1cml000312";
    user = "schausberger";
    wm = wms;
    system = "x86_64-linux";
  };

  # Enable container tools
  modules.system.containers.enable = true;

  # Network performance optimizations
  networking = {
    # Disable dhcpcd on ethernet interface to prevent 30s boot delay
    dhcpcd.enable = false;

    # Use NetworkManager for all interfaces (WiFi and ethernet)
    networkmanager.enable = true;
  };

  # Boot optimizations
  systemd.services = {
    # Don't wait for network-online for faster boot
    "NetworkManager-wait-online".enable = false;

    # Reduce timeout for device detection
    "systemd-udevd".serviceConfig = {
      TimeoutSec = "10s";
    };
  };

  # Hardware configuration
  hardware = {
    # Enable WiFi support
    enableAllFirmware = true;

    # AMD 680M iGPU configuration via profile
    profiles.amdGpu = {
      enable = true;
      variant = "laptop";
    };
  };

  # System maintenance and monitoring (work laptop)
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = true;
    monitoring = {
      enable = true;
      alerts = true;
    };
  };

  # System packages
  # environment.systemPackages = with pkgs; [
  #   # Zed editor wrapper to override ZFS daemon conflict
  #   (pkgs.writeShellScriptBin "zed" ''
  #     exec ${pkgs.zed-editor}/bin/zeditor "$@"
  #   '')

  #   # LAN Mouse - Software KVM switch for sharing mouse and keyboard over network
  #   lan-mouse
  # ];
}
