# Desktop workstation host: AMD gaming/rendering machine with Niri as the only WM.
# Headless-first profile (same shape as m920q): no display manager runs at boot;
# the session starts on monitor hotplug through modules.system.sessionOnDemand.
# Games stream headless via Moonshine — each Moonlight session runs in its own
# compositor, so no local session or monitor is needed. The tty1 getty stays
# enabled as the console of last resort.
{
  inputs,
  lib,
  pkgs,
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
      # Archive client half: the weekly pull of the cold archive.
      ../../modules/system/homelab/archive.nix
      # Log shipping (client half): pushes this host's journald to the m920q
      # Loki through Grafana Alloy.
      ../../modules/system/homelab/logging.nix
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
    # Keychron K6 HE raw HID (VID 0x3434) for VIA and Keychron Launcher;
    # the STM32 DFU rules (0483:df11) come from the base QMK rules.
    keyboard.qmk.keychronSupport = true;

    # DDC/CI brightness control for the external monitors (no internal
    # backlight): exposes /dev/i2c-* for noctalia's ddcutil backend.
    i2c.enable = true;

    profiles.amdGpu = {
      enable = true;
      variant = "desktop";
    };
  };

  # i2c.enable grants /dev/i2c-* to the i2c group; the on-demand session
  # has no local seat, so membership is required for DDC brightness access.
  users.users.${inputs.self.lib.user}.extraGroups = ["i2c"];

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

  # Passwordless power control for the headless host, which has no login
  # session for polkit to authorize against: poweroff is the m920q's
  # `desktop-power off` action, shutdown is Moonshine's stream hooks (a stream
  # end schedules `shutdown +15`, a new stream cancels it with `shutdown -c`).
  security.sudo.extraRules = [
    {
      users = [inputs.self.lib.user];
      commands = [
        {
          command = "/run/current-system/sw/bin/poweroff";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/shutdown";
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
    6666 # m920q kernel netconsole stream (netconsole-receiver below)
    27031
    27032
    27033
    27034
    27035
    27036
  ];

  # Crash forensics receiver for the m920q: its only UART is the ME/AMT
  # virtual port (registering it as a kernel console hangs early boot), so
  # this stands in as its serial console - a netconsole UDP stream of kernel
  # printk. Lines go to this service's journal output, which keeps the trace
  # reboot-independent twice over: /var/log/journal persists here while the
  # m920q is down, and the fleet Alloy ships the journal to the m920q Loki
  # with a persisted cursor, replaying the backlog once that host is back -
  # the trace ends up queryable in Grafana next to every other journal line
  # (host="desktop", unit="netconsole-receiver.service"). A backlog older
  # than Alloy's 24h max_age would stay journal-only. Best effort at the
  # front: the desktop is woken on demand, so a death while this host is off
  # still surfaces only through the m920q's unclean-shutdown alert.
  systemd.services.netconsole-receiver = {
    description = "UDP receiver for the m920q kernel netconsole stream";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat -u UDP-RECV:6666,reuseaddr -";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Moonshine game streaming for remote access via Moonlight.
  # Headless-first: no local session or Steam autostart, so Moonshine's
  # per-stream compositor always launches the primary Steam instance
  # (Steam is single-instance per user; a running desktop Steam would
  # steal the steam:// URL and break the stream — upstream issue #134).
  # powerOff schedules the idle shutdown once a stream (or the game inside it)
  # ends, so a wake-for-gaming session never leaves the ~52 W desktop idling.
  modules.system.moonshine = {
    enable = true;
    powerOff.enable = true;
  };
  modules.system.gaming.enable = true;
  modules.system.emulation.enable = true;

  # Vitals health monitoring, same daemon+CLI as m920q in headless mode:
  # headless=true binds the user daemon to default.target, because
  # graphical-session.target only exists while an on-demand session runs.
  # This host runs no monitoring stack, so the score is exported through the
  # node exporter textfile collector, which the m920q Prometheus already
  # scrapes (job "node-desktop"); m920q scrapes its own daemon on loopback.
  services.vitals = {
    enable = true;
    headless = true;
    textfile.enable = true;
  };

  # Log shipping: journald goes to the m920q Loki over the LAN, resolved by
  # AdGuard the same way as the ntfy endpoint above. The desktop needs no
  # listener or firewall rule of its own.
  modules.system.homelab.logging.shipEndpoint = "http://m920q:3100";
  # Steam game library on the games pool; registered into libraryfolders.vdf
  # by home activation (skipped while Steam runs, applied on next rebuild)
  modules.system.steam.extraLibraryFolders = ["/per/mnt/games/SteamLibrary"];
  # No Rest for the Wicked ships a non-functional Linux depot that makes Steam
  # default to the scout runtime and exec the .exe directly; force GE-Proton
  # per game (priority 250 wins over the global default at 75).
  modules.system.steam.compatTools = {"1371980" = "GE-Proton";};

  # Kill user processes immediately on shutdown instead of waiting 90s
  services.logind.settings.Login.KillUserProcesses = true;

  # Node exporter scraped by the m920q Prometheus (job "node-desktop",
  # firewall 9100 above). Collector list mirrors the node exporter in
  # modules/system/homelab/monitoring.nix. The textfile collector is enabled
  # by services.vitals.textfile, which carries this host's health score to
  # the m920q Prometheus; the maintenance health-check's GC metric is written
  # only where that directory exists.
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

  # energy_uj ships 0400 root-only (CVE-2020-8694) while the node exporter runs
  # unprivileged, and the powercap zone registers after systemd-tmpfiles-setup
  # has already run, so a tmpfiles chmod is a per-boot race (observed losing it
  # on other hosts). The udev add event fires exactly when the zone appears;
  # the KERNEL glob skips the parent intel-rapl device, which has no energy_uj.
  # Activates the built-in rapl collector (node_rapl_package_joules_total,
  # package-0 on this host).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="*:*", RUN+="${pkgs.coreutils}/bin/chmod 0444 /sys/class/powercap/%k/energy_uj"
  '';

  # Motherboard and RAM RGB draw a few watts and are unwanted on this host.
  # The OpenRGB server runs as root with the module's udev rules, and a boot
  # oneshot blanks every controller it detects; a controller it does not
  # support is simply not found and is left untouched, so the unit is safe to
  # keep regardless of how much of the board OpenRGB covers.
  services.hardware.openrgb.enable = true;
  systemd.services.openrgb-off = {
    description = "Blank RGB lighting";
    after = ["openrgb.service"];
    wants = ["openrgb.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.openrgb}/bin/openrgb --mode static --color 000000";
    };
  };

  # PCIe links otherwise keep the BIOS ASPM policy, which leaves them at L0.
  # The powersave policy lets idle links drop to L1, worth a watt or two on a
  # headless host; drop it again if an NVMe or USB device misbehaves.
  boot.kernelParams = ["pcie_aspm.policy=powersave"];

  # System maintenance and monitoring
  modules.system.maintenance = {
    enable = true;
    monitoring = {
      enable = true;
      alerts = true;
      ntfyUrl = "http://${inputs.self.lib.hosts.m920q.tailnetIp}:2586/homelab-alerts";
    };
  };

  # Pull-based GitOps: converge to main automatically, alert on downgrades
  modules.system.comin = {
    enable = true;
    alertNtfyUrl = "http://${inputs.self.lib.hosts.m920q.tailnetIp}:2586/homelab-alerts";
  };

  # Same bless-driven cleanup as m920q (systemd-boot boot counting + reactivation
  # tolerance): activations restart the runner on this long-lived boot, and the
  # running generation's entry is not on the ESP, so the stock unit aborted the
  # whole activation before module import (#237 wrapper requires the module).
  modules.system.bootFallback.enable = true;

  modules.system.homelab.backup = {
    enable = true;
    # The desktop is on irregularly. With Persistent=true a daily timer runs
    # at the first boot after midnight, so the replica follows the sessions
    # instead of waiting for a fixed weekday the machine may not be on. A
    # weekly timer can leave a Tuesday session unbacked-up until the next
    # Monday even though the machine booted several times in between.
    syncoidInterval = "daily";
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
    sanoidDatasets."dpool/games" = {
      # sanoid-only like rpool/eyd/per: opt zfstools out once with
      # `zfs set com.sun:auto-snapshot=false dpool/games`.
      # Steam updates rewrite whole depots, so each retained snapshot pins the
      # replaced bytes: keep the layer small (two dailies, two weeklies, one
      # monthly) because the 1TB backup disk also holds the home and per
      # replicas.
      frequently = 0;
      hourly = 0;
      daily = 2;
      weekly = 2;
      monthly = 1;
      yearly = 0;
    };
    # Replica retention. syncoid never deletes a target snapshot, so without
    # a policy here each replica keeps everything the source ever pruned and
    # the 1TB pool fills with stale nightlies. Monthlies are the long-term
    # layer; the finer layers stay on the source.
    sanoidDatasets."bpool/desktop/home" = {
      hourly = 0;
      daily = 0;
      weekly = 0;
      monthly = 24;
      yearly = 0;
    };
    sanoidDatasets."bpool/desktop/per" = {
      hourly = 0;
      daily = 0;
      weekly = 0;
      monthly = 24;
      yearly = 0;
      # The replica is recursive (per/repos and future children). Without
      # this, sanoid prunes only the parent and every received child
      # snapshot the source ages out stays pinned here forever.
      recursive = true;
    };
    sanoidDatasets."bpool/desktop/games" = {
      # Each game snapshot pins the depots Steam replaced. Six monthlies
      # keep a restore point beyond the current update cycle without
      # letting a year of updates pin the backup disk.
      hourly = 0;
      daily = 0;
      weekly = 0;
      monthly = 6;
      yearly = 0;
    };
    syncoidCommands = {
      "desktop-home-to-bpool" = {
        source = "rpool/eyd/home";
        target = "bpool/desktop/home";
        # -u: the replica is read from the pool, and the service chroot cannot
        # create the mountpoint (same reason as the m920q commands).
        recvOptions = "u";
      };
      "desktop-per-to-bpool" = {
        source = "rpool/eyd/per";
        target = "bpool/desktop/per";
        # Recursive carries /per/repos; without it the replica silently misses
        # the child dataset.
        recursive = true;
        recvOptions = "u";
      };
      # The games pool is the desktop's only non-reproducible bulk data; the
      # snapshot layer above is its sole off-disk history.
      "desktop-games-to-bpool" = {
        source = "dpool/games";
        target = "bpool/desktop/games";
      };
    };
    # Off-site success stamps: the pulls are the routes that leave the
    # chassis, so their age is what the dashboard and the staleness rules
    # watch (modules/system/backup.nix).
    status = {
      enable = true;
      routes = {
        home = {
          unit = "syncoid-desktop-home-to-bpool";
          maxAge = "8d";
          description = "desktop home replica";
        };
        per = {
          unit = "syncoid-desktop-per-to-bpool";
          maxAge = "8d";
          description = "desktop per replica";
        };
        games = {
          unit = "syncoid-desktop-games-to-bpool";
          maxAge = "8d";
          description = "desktop games replica";
        };
        archive-pull = {
          unit = "archive-pull";
          maxAge = "14d";
          description = "archive pulled off-site";
        };
        vault-dr-pull = {
          unit = "vaultwarden-dr-pull";
          maxAge = "14d";
          description = "vaultwarden DR pulled off-site";
        };
      };
    };
  };

  # Chassis-loss copy of the m920q vault: syncoid above only moves this
  # machine's own data, so the vault gets a quarterly sops-encrypted
  # snapshot pulled from the m920q Samba share onto this host's backup
  # pool. Persistent=true makes the timer fire at boot whenever a due run
  # was missed while the machine was off.
  modules.system.homelab.vaultwarden.dr.pull.enable = true;

  # Same idea for the cold archive: the m920q's bpool and dpool share a
  # chassis, so the legacy tree is pulled onto this host's backup pool and
  # verified against the manifest the archive carries.
  modules.system.homelab.archive.pull.enable = true;
}
