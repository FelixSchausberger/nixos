# Desktop workstation host: AMD gaming/rendering machine with Niri as default WM.
# Both VIRTUAL-1 and DP-3 are defined in the niri config. VIRTUAL-1 is always
# enabled for Sunshine remote streaming. DP-3 starts disabled (off) and can be
# toggled on/off via `desktop-display-mode` or the remote-control web UI.
# niri natively handles DP hotplug, so no udev rules or specialisations needed.
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hosts.${hostName};
  inherit (inputs.self.lib) user;

  desktopDisplayModeScript = pkgs.writeShellScriptBin "desktop-display-mode" ''
    set -euo pipefail
    case "''${1:-}" in
      away)
        niri msg output DP-3 off 2>/dev/null || true
        echo away > /run/desktop-current-mode
        ;;
      home)
        niri msg output DP-3 on 2>/dev/null || true
        echo home > /run/desktop-current-mode
        ;;
      status)
        cat /run/desktop-current-mode 2>/dev/null || echo unknown
        ;;
      *)
        echo "Usage: desktop-display-mode {home|away|status}" >&2
        exit 2
        ;;
    esac
  '';
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

  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;

    autoLogin = {
      enable = true;
      inherit (inputs.self.lib) user;
    };

    specialisations = {
      cosmic = {
        wms = ["cosmic"];
        profile = "default";
        extraConfig = {
          imports = [../../modules/system/wm/cosmic.nix];
          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../modules/home/wm/cosmic
          ];
        };
      };
      hyprland = {
        wms = ["hyprland"];
        profile = "default";
        extraConfig = {
          imports = [../../modules/system/wm/hyprland.nix];
          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../home/profiles/desktop/hyprland.nix
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

  boot = {
    # Virtual output for away mode and streaming without occupying physical GPU connectors
    kernelModules = ["vkms"];

    # Auto-import the games data pool (1TB WD Blue SN5000) on boot
    zfs.extraPools = ["dpool"];
  };

  # fwupd metadata refresh intermittently exits with auth errors during activation,
  # which causes nh test activation to report failure despite successful rebuild.
  # Keep fwupd daemon available, but disable the auto-refresh unit/timer.
  systemd.services.fwupd-refresh.enable = false;
  systemd.timers.fwupd-refresh.enable = false;

  fileSystems."/per/games" = {
    device = "dpool/games";
    fsType = "zfs";
  };

  modules.system.ssh.enable = true;

  environment.systemPackages = [
    desktopDisplayModeScript
  ];

  # Allow remote power off from m920q without password prompt
  security.sudo.extraRules = [
    {
      users = [inputs.self.lib.user];
      commands = [
        {
          command = "/run/current-system/sw/bin/poweroff";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/desktop-display-mode";
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

  # Kill user processes immediately on shutdown instead of waiting 90s
  services.logind.killUserProcesses = true;

  # System maintenance and monitoring
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = true;
    monitoring = {
      enable = true;
      alerts = true;
      ntfyUrl = "http://m920q:2586/homelab-alerts";
    };
  };
}
