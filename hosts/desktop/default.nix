# Desktop workstation host: AMD gaming/rendering machine with Niri as the only WM.
# Games stream headless via Moonshine — each Moonlight session runs in its own
# compositor, so no local session or monitor is needed. greetd remains available
# for occasional console logins.
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
      ../../modules/system/gaming.nix
      ../../modules/system/tailscale.nix
      ../../modules/system/backup.nix
      ../../modules/system/hardware/power-management.nix
      ../../modules/system/moonshine.nix
      ../../modules/system/ssh.nix
      ../../modules/system/nixpkgs-overlays.nix
      ../../modules/vitals.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;

    zellijAutoAttach.sessionName = "desktop";
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
    # thermald >= 2.5.12 refuses to start on non-mobile ACPI platform profiles
    # (upstream intel/thermal_daemon#562); kernel TCC throttling and RAPL limits
    # provide thermal protection on this desktop.
    intelCpuThermals = false;
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
    # Auto-import the games data pool (1TB WD Blue SN5000, dpool/games at
    # /per/mnt/games) and USB backup pool (1TB SanDisk Extreme, bpool/desktop
    # at /per/mnt/backup) on boot. Their datasets carry native mountpoints and
    # are mounted by zfs-mount.service (`zfs mount -a`) once all pools finish
    # importing. Keep them out of fileSystems: mount(8) cannot mount non-legacy
    # datasets, so fstab-generated units fail whenever they start before
    # zfs-mount.service (USB pool enumeration timing varies per boot).
    zfs.extraPools = ["dpool" "bpool"];
  };

  # fwupd metadata refresh intermittently exits with auth errors during activation,
  # which causes nh test activation to report failure despite successful rebuild.
  # Keep fwupd daemon available, but disable the auto-refresh unit/timer.
  systemd.services.fwupd-refresh.enable = false;
  systemd.timers.fwupd-refresh.enable = false;

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

  # Moonshine game streaming for remote access via Moonlight.
  # Headless-first: no local session or Steam autostart, so Moonshine's
  # per-stream compositor always launches the primary Steam instance
  # (Steam is single-instance per user; a running desktop Steam would
  # steal the steam:// URL and break the stream — upstream issue #134).
  modules.system.moonshine.enable = true;
  modules.system.gaming.enable = true;

  # Vitals health monitoring, same daemon+CLI as m920q but in GUI mode:
  # headless=false binds the user daemon to graphical-session.target (Niri)
  # instead of default.target.
  services.vitals = {
    enable = true;
    headless = false;
  };
  # Steam game library on the games pool; registered into libraryfolders.vdf
  # by home activation (skipped while Steam runs, applied on next rebuild)
  modules.system.steam.extraLibraryFolders = ["/per/mnt/games/SteamLibrary"];
  # No Rest for the Wicked ships a non-functional Linux depot that makes Steam
  # default to the scout runtime and exec the .exe directly; force GE-Proton
  # per game (priority 250 wins over the global default at 75).
  modules.system.steam.compatTools = {"1371980" = "GE-Proton";};

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
  modules.system.maintenance = {
    enable = true;
    monitoring = {
      enable = true;
      alerts = true;
      ntfyUrl = "http://m920q:2586/homelab-alerts";
    };
  };

  # Pull-based GitOps: converge to main automatically, alert on downgrades
  modules.system.comin = {
    enable = true;
    alertNtfyUrl = "http://m920q:2586/homelab-alerts";
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
}
