# Desktop workstation host: AMD gaming/rendering machine with Niri as default WM.
# Keeps COSMIC as a boot-time specialisation and enables Sunshine for remote streaming.
{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hosts.${hostName};
  # Only import WMs that are in the main config, not specialisation WMs
  # This prevents eager evaluation of all WM modules
in {
  imports =
    [
      ./disko.nix
      ./base-config.nix
      ../../modules/system/specialisations.nix
      ../../modules/system/gaming.nix
      ../../modules/system/homelab
      ../../modules/system/hardware/power-management.nix
      ../../modules/system/sunshine.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Niri home modules loaded at parent level (niri is the default WM)
  # Note: inputs.niri.homeModules.config is already provided via nixosModules.niri
  # (home-manager.sharedModules) in modules/system/wm/niri.nix — do not re-import it here.
  home-manager.users.${inputs.self.lib.user}.imports = [
    ../../home/profiles/desktop/niri.nix.specialisation
  ];

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;
    # user and system use defaults from lib/defaults.nix

    # Cosmic available as a boot-time specialisation
    specialisations = {
      cosmic = {
        wms = ["cosmic"];
        profile = "default";
        extraConfig = {
          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../modules/home/wm/cosmic
          ];
        };
      };
    };
  };

  # Hardware configuration
  hardware = {
    # Desktop-specific hardware configuration
    keyboard.qmk.enable = true;

    # AMD RX 6700XT GPU configuration via profile
    profiles.amdGpu = {
      enable = true;
      variant = "desktop";
    };
  };

  # Wake-on-LAN on the wired ethernet interface
  hardware.profiles.powerManagement = {
    enable = true;
    lanInterface = "eno1";
  };

  # Static LAN IP for predictable access from m920q
  networking.useNetworkd = true;
  networking.networkmanager.enable = lib.mkForce false;
  systemd.network = {
    enable = true;
    networks."10-eno1" = {
      matchConfig.Name = "eno1";
      linkConfig.RequiredForOnline = "routable";
      networkConfig.DHCP = "no";
      address = ["192.168.178.3/24"];
      gateway = ["192.168.178.1"];
      dns = ["192.168.178.1"];
    };
  };

  # Auto-import the games data pool (1TB WD Blue SN5000) on boot
  boot.zfs.extraPools = ["dpool"];
  fileSystems."/per/games" = {
    device = "dpool/games";
    fsType = "zfs";
  };

  modules.system.homelab.tailscale = {
    enable = true;
    udpGROInterface = "eno1";
  };

  # Sunshine game streaming for remote access via Moonlight
  # AMD VAAPI encoding is available via amdgpu driver (hardware.profiles.amdGpu above)
  modules.system.sunshine.enable = true;
  modules.system.gaming.enable = true;

  # System maintenance and monitoring
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = true;
    monitoring = {
      enable = true;
      alerts = true;
    };
  };
}
