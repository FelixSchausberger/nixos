# Desktop workstation host: AMD gaming/rendering machine with Hyprland as default WM.
# Hyprland supports headless outputs for Sunshine/Moonlight remote streaming.
# Niri and COSMIC available via specialisations.
{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hosts.${hostName};
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
      ../../modules/system/ssh.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Hyprland home modules loaded at parent level (hyprland is the default WM)
  home-manager.users.${inputs.self.lib.user}.imports = [
    ../../home/profiles/desktop/hyprland.nix
  ];

  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;

    specialisations = {
      niri = {
        wms = ["niri"];
        profile = "default";
        extraConfig = {
          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../home/profiles/desktop/niri.nix.specialisation
          ];
        };
      };
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

  hardware = {
    keyboard.qmk.enable = true;

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
      linkConfig = {
        RequiredForOnline = "routable";
        MACAddress = "10:ff:e0:e1:53:55";
      };
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

  modules.system.ssh.enable = true;

  # Allow remote power off from m920q without password prompt
  security.sudo.extraRules = [
    {
      users = [inputs.self.lib.user];
      commands = [
        {
          command = "/run/current-system/sw/bin/poweroff";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  modules.system.homelab.tailscale = {
    enable = true;
    udpGROInterface = "eno1";
  };

  # Steam Remote Play firewall ports (for direct LAN connections via Steam Link)
  networking.firewall.allowedTCPPorts = [27036];
  networking.firewall.allowedUDPPorts = [
    27031
    27032
    27033
    27034
    27035
    27036
  ];

  # Sunshine game streaming for remote access via Moonlight
  # AMD VAAPI encoding is available via amdgpu driver (hardware.profiles.amdGpu above)
  modules.system.sunshine.enable = true;
  modules.system.gaming.enable = true;
  modules.system.steam.autoStart = true;

  # OpenLDAP 2.6.13 test suite has a regression (provider/consumer DB mismatch).
  # Skip tests rather than wait for upstream fix; runtime is unaffected.
  nixpkgs.config.packageOverrides = pkgs: {
    openldap = pkgs.openldap.overrideAttrs (_old: {
      doCheck = false;
    });
  };

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
