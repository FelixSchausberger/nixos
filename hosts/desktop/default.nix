# Desktop workstation host: AMD gaming/rendering machine with Niri as the only WM.
# Headless-first profile (same shape as m920q): no display manager runs at boot;
# the session starts on monitor hotplug through modules.system.sessionOnDemand.
# Games stream headless via Moonshine — each Moonlight session runs in its own
# compositor, so no local session or monitor is needed. The tty1 getty stays
# enabled as the console of last resort.
{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hosts.${hostName};
  inherit (hostInfo) lanMac;
in {
  imports =
    [
      ./disko.nix
      ./base-config.nix
      ../../modules/system/gaming.nix
      ../../modules/system/emulation.nix
      ../../modules/system/tailscale.nix
      ../../modules/system/backup.nix
      ../../modules/system/hardware/power-management.nix
      ../../modules/system/moonshine.nix
      ../../modules/system/ssh.nix
      ../../modules/system/nixpkgs-overlays.nix
      ../../modules/system/boot-fallback.nix
      # Vaultwarden client half only: the DR pull timer (dr.pull) that
      # fetches the quarterly snapshot off the m920q Samba share.
      ../../modules/system/homelab/vaultwarden.nix
      ../../modules/vitals.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;

    zellijAutoAttach.sessionName = "desktop";

    # Headless-first like m920q: the GUI stack stays in the base closure, but
    # no display manager starts a session at boot — the session comes up on
    # monitor (DP/HDMI) hotplug instead. guiApps stays true: unlike a server,
    # this host keeps its desktop application set for local sessions and gaming.
    autoStartSession = false;
    guiApps = true;
  };

  # Single-compositor guarantee: the on-demand session starts niri.service
  # itself, so UWSM must not also manage a Wayland session (same as m920q).
  programs.uwsm.enable = lib.mkForce false;

  modules.system.sessionOnDemand.enable = true;

  hardware = {
    keyboard.qmk.enable = true;

    profiles.amdGpu = {
      enable = true;
      variant = "desktop";
    };
  };

  # Wake-on-LAN on the wired ethernet interface. Wake is LAN-local: magic
  # packets cannot traverse Tailscale (tailscale/tailscale#306), so remote
  # wake and shutdown are driven from the phone over Tailscale SSH to the
  # always-on m920q (`ssh m920q desktop-power on|off`).
  hardware.profiles.powerManagement = {
    enable = true;
    lanInterface = "eno1";
    lanMacAddress = lanMac;
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
        MACAddress = lanMac;
      };
      networkConfig.DHCP = "no";
      address = ["${hostInfo.ip}/24"];
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

  # Unattended hang recovery for a headless-first machine: a wedged kernel or a
  # failed boot would otherwise stay unreachable until someone reaches the
  # console. The AMD FCH TCO watchdog binds on this board: /dev/watchdog0
  # reports "SP5100 TCO timer" (driver heartbeat 60s, nowayout=0), and the
  # lockup panics, panic=30 and emergency deadman cover hangs the watchdog
  # cannot see (e.g. a boot that never reaches userspace).
  modules.system.watchdog = {
    enable = true;
    watchdogKernelModules = ["sp5100_tco"];
  };

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

  # Steam Remote Play firewall ports (for direct LAN connections via Steam
  # Link), plus 9100 for the node exporter the m920q Prometheus scrapes
  # (job "node-desktop").
  networking.firewall.allowedTCPPorts = [
    9100
    27036
  ];
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
  modules.system.emulation.enable = true;

  # Vitals health monitoring, same daemon+CLI as m920q in headless mode:
  # headless=true binds the user daemon to default.target, because
  # graphical-session.target only exists while an on-demand session runs.
  services.vitals = {
    enable = true;
    headless = true;
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

  # Node exporter scraped by the m920q Prometheus (job "node-desktop",
  # firewall 9100 above). Collector list mirrors the node exporter in
  # modules/system/homelab/monitoring.nix; no textfile collector here — the
  # maintenance health-check only writes GC metrics when the directory exists.
  # hwmon carries the amdgpu power1_average series (GPU watts) unprivileged.
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [
      "systemd"
      "processes"
      "filesystem"
      "diskstats"
      "netdev"
      "meminfo"
      "loadavg"
      "zfs"
      "hwmon"
      "thermal_zone"
    ];
  };

  # RAPL energy counters ship 0400 root-only (CVE-2020-8694) while the node
  # exporter runs unprivileged; tmpfiles re-applies the readable mode after
  # every boot, activating the built-in rapl collector
  # (node_rapl_package_joules_total, AMD package-0 on this host). Effective on
  # next boot, or immediately via `systemd-tmpfiles --create`.
  systemd.tmpfiles.rules = [
    "z /sys/class/powercap/*/energy_uj 0444 - - -"
  ];

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

  # Same bless-driven cleanup as m920q (systemd-boot boot counting + reactivation
  # tolerance): activations restart the runner on this long-lived boot, and the
  # running generation's entry is not on the ESP, so the stock unit aborted the
  # whole activation before module import (#237 wrapper requires the module).
  modules.system.bootFallback.enable = true;

  modules.system.homelab.backup = {
    enable = true;
    syncoidInterval = "weekly";
    # rpool/eyd/per is sanoid-only here too: the persistent
    # com.sun:auto-snapshot=false dataset property opts zfstools out
    # (one-time `zfs set`; retained history destroyed once manually).
    # Retention follows the m920q pattern agreed 2026-09-16.
    sanoidDatasets."rpool/eyd/per" = {
      frequently = 8;
      hourly = 24;
      daily = 7;
      weekly = 2;
      monthly = 3;
      yearly = 0;
      recursive = true;
    };
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

  # Chassis-loss copy of the m920q vault: syncoid above only moves this
  # machine's own data, so the vault gets a quarterly sops-encrypted
  # snapshot pulled from the m920q Samba share onto this host's backup
  # pool. Persistent=true makes the timer fire at boot whenever a due run
  # was missed while the machine was off.
  modules.system.homelab.vaultwarden.dr.pull.enable = true;
}
