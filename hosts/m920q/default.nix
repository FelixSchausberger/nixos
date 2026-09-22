# ThinkCentre M920q dual-role host: always-on homelab server whose niri
# session starts on demand when the bedroom projector is hotplugged
# (modules.system.sessionOnDemand). The GUI stack lives in the base closure, so
# no NixOS specialisation switch is involved. AirPlay casting renders into the
# running session over Wayland. Prioritizes low idle power: the compositor only
# runs while a display is connected.
#
# Optimal BIOS (Setup F1) for this NixOS config — not declaratively settable
# via Nix (NVRAM, outside /nix/store); kept here as single source of truth:
#  Startup:  UEFI Only, CSM Disabled, Secure Boot Disabled (systemd-boot unsigned),
#            Boot Priority: NVMe rpool first, USB last, Network Boot Disabled
#  Devices:  SATA AHCI, Serial Port Enabled 3F8/IRQ4 (for console=ttyS0 SOL),
#            Video: Auto, Audio Disabled (headless), USB Legacy Enabled
#  Advanced: CPU: VT-x Enabled, VT-d Enabled, TXT Disabled, Hyper-Threading Enabled,
#            C-States Enabled, Turbo Enabled, Above 4G Decoding Disabled
#            Intel Manageability: Enabled, Ctrl-P Enabled, SOL/IDER/KVM Enabled,
#            VT-UTF8 115200n8, Network DHCP (reserve .10 in Fritz!Box), USB Prov Disabled
#  Security: TPM Enabled (if present), SGX Software Controlled / State Disabled + nosgx
#            kernel param (intentional, SGX deprecated, silences "SGX disabled" line),
#            Secure Boot Disabled, Intel TXT Disabled, Computrace Disabled
#  Power:    After Power Loss: Power On, Wake on LAN Enabled (eno1), Deep Sleep Disabled,
#            Automatic Power On Disabled, Enhanced Power Saving Disabled
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "m920q";
  hostInfo = inputs.self.lib.hosts.${hostName};
  inherit (inputs.self.lib) user;

  ntfySmartNotify = pkgs.writeShellScript "ntfy-smart-notify" ''
    exec ${pkgs.curl}/bin/curl -s -o /dev/null \
      -H "Title: SMART Alert: $SMARTD_DEVICESTRING" \
      -H "Priority: urgent" \
      -H "Tags: warning,cd" \
      -d "$SMARTD_FAILTYPE on $SMARTD_DEVICESTRING: $SMARTD_MESSAGE" \
      http://127.0.0.1:2586/homelab-alerts
  '';

  # Desktop power control, invoked over Tailscale SSH from the phone:
  #   ssh m920q desktop-power on|off|status
  # Magic packets are L2 broadcasts and cannot traverse Tailscale
  # (tailscale/tailscale#306), so this runs on the always-on, LAN-connected
  # m920q and replays them as a LAN broadcast; shutdown is a key-based ssh
  # to the desktop. The invoking user's persisted SSH key authenticates the
  # m920q -> desktop hop, and the desktop's user-scoped NOPASSWD rule
  # authorizes poweroff.
  desktopPower = pkgs.writeShellApplication {
    name = "desktop-power";
    runtimeInputs = with pkgs; [wakeonlan iputils openssh curl coreutils];
    text = ''
      host=${inputs.self.lib.hosts.desktop.ip}
      mac=${inputs.self.lib.hosts.desktop.lanMac}
      broadcast=192.168.178.255

      up() { ping -c 1 -W 1 "$host" >/dev/null 2>&1; }

      notify() {
        curl -s -o /dev/null -H "Title: $1" -H "Priority: $3" -H "Tags: $4" -d "$2" \
          http://127.0.0.1:2586/desktop-power || true
      }

      case "''${1:-}" in
        on | wake)
          if up; then echo "desktop already up"; exit 0; fi
          wakeonlan -i "$broadcast" "$mac"
          for _ in $(seq 1 48); do
            if up; then
              notify "Desktop is up" "reachable after wake request" default electric_plug
              echo "desktop up"
              exit 0
            fi
            sleep 5
          done
          notify "Desktop did not wake" "still unreachable after 240s" high warning
          echo "desktop did not wake" >&2
          exit 1
          ;;
        off | shutdown)
          if ! up; then echo "desktop already off"; exit 0; fi
          if ! ssh -o BatchMode=yes -o ConnectTimeout=5 desktop sudo -n /run/current-system/sw/bin/poweroff; then
            notify "Desktop shutdown failed" "poweroff over SSH failed" high warning
            echo "poweroff over ssh failed" >&2
            exit 1
          fi
          for _ in $(seq 1 30); do
            if ! up; then
              notify "Desktop is off" "powered down after request" default crescent_moon
              echo "desktop off"
              exit 0
            fi
            sleep 3
          done
          notify "Desktop still on" "poweroff accepted but host stayed reachable" high warning
          echo "desktop still reachable after poweroff" >&2
          exit 1
          ;;
        status)
          if up; then echo up; else echo down; fi
          ;;
        *)
          echo "usage: desktop-power on|off|status" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  imports =
    [
      ./disko.nix
      ../shared-tui.nix
      ../boot-zfs.nix
      ../../modules/system/boot-fallback.nix
      ../../modules/system/homelab
      ../../modules/system/tailscale.nix
      ../../modules/system/backup.nix
      ../../modules/system/hardware/power-management.nix
      ../../modules/system/media-client.nix
      ../../modules/system/airplay-receiver.nix
      inputs.stylix.nixosModules.stylix
      ../../modules/system/stylix-catppuccin.nix
      ../../modules/system/nixpkgs-overlays.nix
      ../../modules/vitals.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui wms;
    performanceProfile = "server-efficiency";

    zellijAutoAttach.sessionName = "homelab";

    # The GUI stack is part of the base closure (niri via hostInfo.wms), but the
    # session starts on projector hotplug through modules.system.sessionOnDemand
    # rather than a display manager at boot.
    autoStartSession = false;
  };

  # Single-compositor guarantee: the on-demand session starts niri.service
  # itself, so UWSM must not also manage a Wayland session.
  programs.uwsm.enable = lib.mkForce false;

  modules.system.sessionOnDemand.enable = true;

  # Firmware updates are a hardware concern independent of the session.
  modules.system.firmware.enable = true;

  services.vitals = {
    enable = true;
    headless = true;
  };

  environment.systemPackages = with pkgs;
    [
      wakeonlan # Send magic packets to wake desktop from homelab
      desktopPower # Wake/shut down the desktop over Tailscale SSH from the phone
      powertop # CPU C-state residency, wakeups/sec, power estimation
      iotop # Per-process disk IO monitoring
      htop # Process monitoring (already included via btop but useful)
      lm_sensors # Temperature, voltage, fan speed via hwmon
      immich-go # Bulk import tool for Immich
    ]
    ++ [
      inputs.iris.packages.${pkgs.stdenv.hostPlatform.system}.iris
    ];

  # Mosh for roaming interactive sessions; survives network changes and
  # suspend. UDP range below covers mosh-server ports (11 concurrent sessions).
  programs.mosh = {
    enable = true;
    # Port range is declared manually above to keep it narrow
    openFirewall = false;
  };

  networking.firewall.allowedUDPPortRanges = [
    {
      from = 60000;
      to = 60010;
    }
  ];

  boot.kernelParams = lib.mkAfter [
    "zfs.zfs_arc_max=8589934592"
    "zfs.zfs_arc_min=536870912"
    # Do NOT add "console=ttyS0,115200n8" here. The ttyS0 UART on this board
    # is the ME/AMT virtual serial (PCI 00:16.3), not the physical COM port,
    # and registering it as a kernel console hangs the boot silently right
    # after the EFI stub (no console ever registers; Sep 2026: every bootable
    # generation lacks it, five hanging generations across 6.18.48/6.12.107
    # all had it, menu-editor removal test boots). Post-boot SOL login still
    # works via serial-getty@ttyS0 below once AMT has an IP.
    # SGX is deprecated/unused on this headless homelab and the BIOS leaves it
    # disabled. Suppress the informational "x86/cpu: SGX disabled by BIOS"
    # message that otherwise appears as the last log line before boot stalls on
    # an unrelated failure, which misleads diagnosis.
    "nosgx"
    # Hide informational spam (ACPI AE_ALREADY_EXISTS flood, ~56 lines) so a
    # real hang point is visible on console/SOL photos. Errors still journaled.
    "loglevel=3"
  ];

  # A getty on the AMT serial console: recover a text login via Serial-over-LAN
  # with no monitor attached. Works independently of the GUI/tty1 config.
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = ["getty.target"];
    unitConfig.After = ["dev-ttyS0.device"];
  };

  # Unattended hang recovery (hardware watchdog, lockup-to-panic, emergency
  # deadman) is configured under modules.system.watchdog below. It covers
  # runtime hangs only; early-boot hangs (systemd not yet running) still need
  # AMT or the console.

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Follow the 6.18 line (currently 6.18.48, also the nixpkgs default again
  # since the #142 lock refresh). History: #133 pinned LTS 6.12 because 6.18.48
  # appeared to hang before journald (5 failed boots), but the hangs were later
  # traced to the ME/AMT console=ttyS0 UART (see kernelParams above; removal
  # test boots), not the kernel — so 6.18.48 gets a retest instead of a fresh
  # unpin. The explicit pin (not the floating default) holds this line if
  # upstream flips the default again. If a 6.18 boot hangs, boot the previous
  # generation from the systemd-boot menu; boot-fallback-cleanup removes only
  # proven-exhausted entries. The ZFS module rebuild follows the pinned kernel
  # via the hosts/boot-zfs.nix override. No new flake input:
  # linuxPackages_6_18 ships in the existing nixpkgs pin (cached).
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_18;

  services.xserver.videoDrivers = lib.mkDefault [
    "modesetting"
    "intel"
  ];

  networking.hostId = lib.mkForce "b580701b";

  networking.useNetworkd = true;
  networking.networkmanager.enable = lib.mkForce false;

  systemd.network = {
    enable = true;
    networks = {
      "10-eno1" = {
        matchConfig.Name = "eno1";
        # Fritz!Box LAN side runs at MTU 1492 (mirrors its PPPoE WAN MTU).
        # Keep the client at 1492 so full-size IPv6 packets aren't dropped
        # before ICMPv6 PMTUD can adapt (measured: payload 1452 = 1500 total fails
        # even to the router; 1444 = 1492 works).
        linkConfig = {
          MTUBytes = "1492";
          RequiredForOnline = "routable";
        };
        networkConfig.DHCP = "no";
        address = ["192.168.178.2/24"];
        gateway = ["192.168.178.1"];
        domains = ["local"];
      };
    };
    wait-online = {
      extraArgs = ["--interface=eno1"];
    };
  };

  # Network daemons must not be restarted mid-deploy: networkd owns the LAN link
  # (static IP, MTU), resolved handles DNS, tailscaled the tailnet, and AdGuard
  # is the LAN DNS server. switch-to-configuration otherwise restarts any unit
  # whose file changed, which can drop the SSH/deploy connection. The restarts
  # are deferred to the nightly maintenance window (maintenance.deferredRestarts).
  systemd.services.systemd-networkd.restartIfChanged = lib.mkForce false;
  systemd.services.systemd-resolved.restartIfChanged = lib.mkForce false;
  systemd.services.tailscaled.restartIfChanged = lib.mkForce false;
  systemd.services.adguardhome.restartIfChanged = lib.mkForce false;

  # The network-maintenance sanity gate pre-checks that these still exist in the
  # rendered network config; fail loudly if someone removes them.
  assertions = [
    {
      assertion = builtins.elem "192.168.178.2/24" (config.systemd.network.networks."10-eno1".address or []);
      message = "m920q: 10-eno1 must keep static address 192.168.178.2/24 (network-maintenance sanity gate depends on it)";
    }
    {
      assertion = builtins.elem "192.168.178.1" (config.systemd.network.networks."10-eno1".gateway or []);
      message = "m920q: 10-eno1 must keep gateway 192.168.178.1 (network-maintenance sanity gate depends on it)";
    }
    {
      # Production runs the AirPlay receiver in gui mode; nothing in the VM
      # tests exercises that layer (tests-vm runs headless), so pin the
      # niri-session.target bindings at eval time.
      assertion = let
        ux = config.systemd.user.services.uxplay or null;
      in
        ux
        != null
        && builtins.elem "niri-session.target" (ux.after or [])
        && builtins.elem "niri-session.target" (ux.wantedBy or []);
      message = "m920q: uxplay gui service must stay bound to niri-session.target (wayland socket availability)";
    }
    {
      # Bedroom deployment: nothing scheduled may wake the disks between
      # 00:00 and 09:00. smartd slots are (S/../.././HH) per man 5 smartd.conf;
      # the rendered self-test schedule must not start inside that window.
      assertion =
        builtins.match
        ".*(S/../../\\./0[0-8]|L/../../\\./0[0-8]).*"
        config.services.smartd.defaults.autodetected
        == null;
      message = "smartd schedule must not fire inside the 00:00-09:00 quiet window";
    }
  ];

  boot.kernelModules = ["vkms"];

  # KillMode "mixed": SIGTERM to the daemon, SIGKILL to the rest of its cgroup.
  # A nix-daemon restart during switch-to-configuration otherwise waits on the
  # daemon's worker processes to exit, which can stall a rebuild; mixed bounds
  # that wait while still tearing the whole cgroup down.
  systemd.services.nix-daemon.serviceConfig.KillMode = lib.mkForce "mixed";

  systemd.sockets.nix-daemon.enable = false;
  systemd.sockets.determinate-nixd.enable = false;

  systemd.units."home-${user}-.cache-zellij.mount" = {
    overrideStrategy = lib.mkForce "asDropin";
    text = lib.mkForce ''
      [Mount]
      LazyUnmount=yes
    '';
  };

  fileSystems."/per".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  services = {
    geoclue2.enable = lib.mkForce false;

    dbus.implementation = lib.mkForce "dbus";

    journald = {
      settings.Journal = {
        RateLimitIntervalSec = "30s";
        RateLimitBurst = 100;
        SystemMaxUse = "500M";
        SystemMaxFileSize = "50M";
        Compress = "yes";
        ForwardToSyslog = "no";
      };
    };
  };

  # Bluetooth drives the JBL Flip 6 audio sink (projector kiosk and general
  # music playback) and a BT Steam Controller if one is used. Pairings persist
  # via environment.persistence."/per" below. Experimental exposes device
  # battery; KernelExperimental enables ISO sockets for recent controllers.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      ControllerMode = "dual";
      Experimental = true;
      KernelExperimental = true;
    };
  };

  # Headless-first host: no login prompt on tty1 (it would leak hostname and
  # username to the projector room, and the on-demand compositor uses the DRM
  # seat directly). Emergency shells (sulogin via rescue/emergency) and SSH are
  # unaffected. A bare Restart=no is not enough: getty@tty1 still starts from
  # getty.target at boot.
  systemd.units."getty@tty1" = {
    enable = false;
  };

  # Root ownership signals tmpfiles that subdirectory ownership transitions are intentional
  systemd.tmpfiles.rules = [
    "d /per/mnt/data/Media 0755 root root -"
  ];

  hardware.profiles.powerManagement = {
    enable = true;
    lanInterface = "eno1";
    lanMacAddress = "e8:6a:64:9f:a0:50";
    suppressLeds = true;
    # thermald >= 2.5.12 refuses to start on non-mobile ACPI platform profiles
    # (upstream intel/thermal_daemon#562); kernel TCC throttling and RAPL limits
    # provide thermal protection on this desktop.
    intelCpuThermals = false;
  };

  systemd.timers.zfs-snapshot-frequent.enable = lib.mkForce false;

  services.smartd = {
    enable = true;
    # Self-tests run in the awake window (14:00), not at night: a short test
    # on a 2.5" HDD is ~30 min of constant seeking, audible in the bedroom
    # (observed 02:18-02:48, 2026-09-16). Quiet window is 00:00-09:00; the
    # assertions entry keeps any future schedule edit inside it.
    defaults.autodetected = "-a -s (S/../.././14|L/../../7/14) -m <nomailer> -M exec ${ntfySmartNotify}";
    notifications.wall.enable = false;
    notifications.mail.enable = false;
  };

  modules.system.mediaClient.enable = true;

  # Bedroom quiet window (00:00-09:00): EPP drop + no turbo keeps the single
  # chassis blower on its slowest curve overnight. Timers below move every
  # non-by-the-second job cluster into the awake window; the same rule used
  # for smartd self-tests (14:00) applies here.
  modules.system.nightQuiet.enable = true;
  systemd.timers."zfs-snapshot-weekly".timerConfig.OnCalendar = lib.mkForce "Sun 13:15:00";
  systemd.timers."zfs-snapshot-monthly".timerConfig.OnCalendar = lib.mkForce "Sun *-*-01..07 13:15:00";
  systemd.timers."zpool-trim".timerConfig.OnCalendar = lib.mkForce "Sun 13:20:00";
  systemd.timers.fstrim.timerConfig.OnCalendar = lib.mkForce "Sun 13:25:00";
  systemd.timers."nextcloud-cleanup".timerConfig.OnCalendar = lib.mkForce "Sun 13:30:00";
  systemd.timers."nixos-cleanup".timerConfig.OnCalendar = lib.mkForce "Sun 12:45:00";

  # AirPlay receiver renders into the on-demand niri session (waylandsink), so a
  # MacBook mirror appears as a fullscreen window over the desktop and
  # disappears when mirroring stops. It starts and stops with the session
  # (niri-session.target), which only runs while a display is connected.
  modules.system.airplayReceiver = {
    enable = true;
    mode = "gui";
  };

  hardware.steam-hardware.enable = true;

  # udev autoloads the BIOS OC watchdog (P2SB sideband) alongside the
  # initrd-forced iTCO_wdt, and whichever registers first wins /dev/watchdog0 —
  # systemd was petting intel_oc_wdt while iTCO_wdt sat unpets on watchdog1.
  # Blacklist it so the standard PCH TCO timer deterministically owns
  # /dev/watchdog0. Needs a reboot to take effect.
  boot.blacklistedKernelModules = ["intel_oc_wdt"];

  modules.system = {
    # Unattended hang recovery. The hardware watchdog resets a wedged kernel;
    # detectable lockups become panics that reboot (panic=30); and if systemd
    # lands in emergency/rescue the deadman auto-reboots after a grace period
    # so systemd-boot boot counting rolls back to a working generation instead
    # of idling locked out of SSH/Tailscale/network. A human at the console can
    # cancel the deadman with: systemctl stop emergency-deadman.
    # iTCO_wdt is the watchdog device on this Intel chipset.
    watchdog = {
      enable = true;
      watchdogKernelModules = ["iTCO_wdt"];
    };

    stylix-catppuccin.enable = true;
    containers.enable = true;
    # Bless-driven cleanup: generations whose boot entries exhausted their
    # tries are deleted once enough good generations exist (see module).
    bootFallback.enable = true;
    # Pull-based GitOps: converge to main automatically. m920q hosts the ntfy
    # endpoint itself, so alerts go through the loopback address.
    comin = {
      enable = true;
      alertNtfyUrl = "http://127.0.0.1:2586/homelab-alerts";
      # Development host: poll the local checkout so jjtest deploys
      # testing-m920q with switch-to-configuration test (no bootloader change)
      # seconds after the bookmark moves, without a GitHub round trip.
      localRemote.enable = true;
    };
    maintenance = {
      enable = true;
      monitoring = {
        enable = true;
        alerts = true;
      };
      # Network daemon restarts are deferred to a nightly window (04:00) so
      # daytime deploys never drop the link; see restartIfChanged = false above.
      deferredRestarts = {
        enable = true;
        services = [
          "systemd-networkd"
          "systemd-resolved"
          "tailscaled"
          "adguardhome"
        ];
        networkSanity = {
          interface = "eno1";
          address = "192.168.178.2/24";
          gateway = "192.168.178.1";
        };
        # Reboots are opt-in: a kernel update only takes effect after a reboot,
        # but that must not destroy the long-lived homelab Zellij session. The
        # maintenance module already sends an ntfy "Reboot Pending" alert when a
        # kernel is deployed-but-not-booted, so reboot manually when convenient.
        # (Also guards the 6.18.48 hang: no nightly auto-reboot into a
        # hanging entry while boot entries are untrusted.)
        autoRebootForKernel = false;
      };
      # m920q hosts the ntfy endpoint and is always on, so it watches the
      # lock-refresh CI for every host; interactive `update` failures are
      # visible on the invoking host already.
      lockRefreshWatch.enable = true;
    };
  };

  boot.zfs.extraPools = [
    "dpool"
    "bpool"
  ];

  # Non-critical pools must never drag the whole system into emergency mode.
  # A failing mount of dpool/data or bpool/backup (e.g. USB backup drive not
  # present at boot) previously failed local-fs.target, which dropped systemd
  # into emergency and locked out SSH/Tailscale/network entirely. Automount (+
  # noauto) makes these lazy: they mount on first access instead of at boot,
  # so a failure becomes a per-open error rather than a system-wide event.
  fileSystems = {
    "/per/mnt/data" = {
      device = "dpool/data";
      fsType = "zfs";
      neededForBoot = false;
      options = ["noauto" "x-systemd.automount"];
    };
    "/per/mnt/backup" = {
      device = "bpool/backup";
      fsType = "zfs";
      neededForBoot = false;
      options = ["noauto" "x-systemd.automount"];
    };
  };

  # Service data predates the services/ domain split. The move ships with the
  # dataPath changes in the same commit: nixpkgs' nextcloud setup runs
  # maintenance:install when config.php is missing (against the existing
  # non-empty DB -> failure -> restart loop), and comin switches automatically
  # on merge, so the move can only happen inside activation, before units
  # restart. /per/mnt/data is automounted: the condition tests trigger the
  # mount, and an absent pool makes them false, so this no-ops when dpool is
  # unavailable. A pre-existing target aborts nothing - the old dir stays put
  # for manual reconciliation rather than a blind merge.
  system.activationScripts.migrateServiceData = ''
    if [ -d /per/mnt/data/nextcloud ] && [ ! -e /per/mnt/data/services/nextcloud ]; then
      mkdir -p /per/mnt/data/services
      mv /per/mnt/data/nextcloud /per/mnt/data/services/nextcloud
    fi
    if [ -d /per/mnt/data/immich ] && [ ! -e /per/mnt/data/services/immich ]; then
      mkdir -p /per/mnt/data/services
      mv /per/mnt/data/immich /per/mnt/data/services/immich
    fi
  '';

  modules.system.homelab = {
    adguardhome.enable = true;
    backup = {
      enable = true;
      # rpool/eyd/per is sanoid-only on this host: zfstools opted out via
      # com.sun:auto-snapshot=false (persistent dataset property, one-time
      # `zfs set` at property level - its 15-min frequent layer moved here
      # via frequently=8). Retention cut 2026-09-16: monthly 12->3, yearlies
      # dropped; two overlapping engines pinned 144G of snapshot-unique
      # data on rpool (2026-09-15 incident).
      sanoidDatasets."rpool/eyd/per" = {
        frequently = 8;
        hourly = 24;
        daily = 7;
        weekly = 2;
        monthly = 3;
        yearly = 0;
        recursive = true;
      };
      sanoidDatasets."dpool/data" = {
        hourly = 24;
        daily = 7;
        weekly = 4;
        monthly = 12;
        yearly = 1;
      };
      syncoidCommands."dpool-data-to-bpool-backup" = {
        source = "dpool/data";
        target = "bpool/backup/data";
      };
    };
    immich = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      # mediaLocation keeps the module default (/per/mnt/data/services/immich), so the
      # Media tree stays free for user-curated, externally indexed photos.
      # thumbs and encoded-video are latency-sensitive (served on every timeline scroll).
      # Placing them on NVMe (rpool/eyd/per) avoids random-read stalls on the SMR SATA dpool.
      # Originals stay on dpool where sequential read performance is acceptable.
      thumbsPath = "/per/immich/thumbs";
      encodedVideoPath = "/per/immich/encoded-video";
    };
    monitoring = {
      enable = true;
      alerting.enable = true;
    };
    # Garmin health-data pipeline: InfluxDB store + fetcher + Grafana
    # dashboard. Calendar overlay rides on Nextcloud (calendar.enable
    # defaults to nextcloud.enable).
    garmin.enable = true;
    navidrome = {
      enable = true;
      openFirewall = true;
    };
    jellyfin = {
      enable = true;
      openFirewall = true;
    };
    nextcloud = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      dataPath = "/per/mnt/data/services/nextcloud";
    };
    caddyProxy = {
      enable = true;
      tailnetDomain = "m920q.tailf2f0ca.ts.net";
    };
    homepage.enable = true;
    ntfy.enable = true;
    samba.enable = true;
    tailscale = {
      enable = true;
      # Tailscale SSH for phone/Termux access: tailscaled authenticates
      # tailnet clients by device identity, no key management needed.
      openSSH = true;
      advertiseRoutes = ["192.168.178.0/24"];
      udpGROInterface = "eno1";
      # The phone has dropped off the tailnet for unexplained multi-minute
      # stretches (on the move and, once, on home WiFi). This host is always
      # on, so it probes the phone and timestamps transitions, alerting via
      # the local ntfy instance.
      peerMonitor = {
        enable = true;
        peer = "pixel-9a";
        alertNtfyUrl = "http://127.0.0.1:2586/homelab-alerts";
      };
    };
    ssh.enable = true;
    zellijWeb = {
      enable = true;
      tailnetDomain = "m920q.tailf2f0ca.ts.net";
    };
    opencodeWeb = {
      enable = true;
      tailnetDomain = "m920q.tailf2f0ca.ts.net";
    };
  };
}
