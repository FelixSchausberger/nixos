# Desktop workstation host: AMD gaming/rendering machine with Niri as the only WM.
# Moonshine provides headless game streaming in isolated Wayland compositors,
# eliminating the need for virtual outputs (vkms/Virtual-1).
# DP-3 can be toggled via `desktop-display-mode` for power saving.
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
      ../../modules/system/gaming.nix
      ../../modules/system/tailscale.nix
      ../../modules/system/backup.nix
      ../../modules/system/hardware/power-management.nix
      inputs.moonshine.nixosModules.default
      ../../modules/system/moonshine.nix
      ../../modules/system/ssh.nix
      ../../modules/system/nixpkgs-overlays.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;

    zellijAutoAttach.sessionName = "desktop";

    autoLogin = {
      enable = true;
      inherit (inputs.self.lib) user;
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
      dns = [
        "192.168.178.2"
        "192.168.178.1"
      ];
    };
  };

  boot = {
    # Auto-import the games data pool (1TB WD Blue SN5000) and USB backup pool (1TB SanDisk Extreme) on boot
    zfs.extraPools = ["dpool" "bpool"];
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

  # Moonshine game streaming for remote access via Moonlight
  # Isolated compositor per stream; no virtual outputs needed
  modules.system.moonshine.enable = true;
  modules.system.gaming.enable = true;
  modules.system.steam.autoStart = true;

  # OpenLDAP 2.6.13 test suite has a regression (provider/consumer DB mismatch).
  # Skip tests rather than wait for upstream fix; runtime is unaffected.
  # Warns once nixpkgs ships a fixed version so the override can be removed.
  nixpkgs.config.packageOverrides = pkgs: let
    regressionFixed = lib.versionAtLeast pkgs.openldap.version "2.6.14";
  in {
    openldap =
      lib.warnIf regressionFixed
      "OpenLDAP ${pkgs.openldap.version} is fixed; remove the doCheck=false override"
      (pkgs.openldap.overrideAttrs (_old: {
        doCheck = false;
      }));
  };

  # Kill user processes immediately on shutdown instead of waiting 90s
  services.logind.settings.Login.KillUserProcesses = true;

  # System maintenance and monitoring
  # autoUpdate is disabled: lock updates flow through the reviewed
  # weekly-updates CI PR instead of per-host `nix flake update`, which
  # otherwise diverged host locks and caused package downgrades.
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = false;
    monitoring = {
      enable = true;
      alerts = true;
      ntfyUrl = "http://m920q:2586/homelab-alerts";
    };
  };

  modules.system.homelab.backup = {
    enable = true;
    syncoidInterval = "weekly";
    syncoidCommands = {
      "desktop-home-to-bpool" = {
        source = "rpool/eyd/home";
        target = "bpool/desktop/home";
      };
      "desktop-per-to-bpool" = {
        source = "rpool/eyd/per";
        target = "bpool/desktop/per";
      };
    };
  };

  fileSystems."/per/mnt/backup" = {
    device = "bpool/desktop";
    fsType = "zfs";
    neededForBoot = false;
  };
}
