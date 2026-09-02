# ThinkCentre M920q dual-role host: headless homelab server with opt-in GUI
# mode (niri specialisation via boot menu or manual mode-switch). AirPlay
# casting runs headless (kmssink, udev-triggered) without any session.
# Prioritizes low idle power while keeping a Niri specialisation available for local media use.
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
in {
  imports =
    [
      ./disko.nix
      ../shared-tui.nix
      ../boot-zfs.nix
      ../../modules/system/m920q.nix
      ../../modules/system/specialisations.nix
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

    specialisations = {
      niri = {
        wms = ["niri"];
        profile = "default";
        extraConfig = {
          pkgs,
          lib,
          ...
        }: {
          imports = [
            ../../modules/system/wm/niri.nix
          ];

          modules.system.airplayReceiver.mode = "gui";

          hostConfig.isGui = lib.mkForce true;

          hardware.graphics = {
            enable = true;
            enable32Bit = true;
          };

          programs.niri = {
            enable = lib.mkForce true;
            package = pkgs.niri;
          };
          # Single-compositor guarantee: greetd owns tty1 and autologins into
          # niri-session, which starts niri.service and graphical-session.target.
          # UWSM would launch a second niri instance racing the home-module units.
          programs.uwsm.enable = lib.mkForce false;

          services.greetd = {
            enable = true;
            settings = {
              # Fallback text login prompt on tty1 after the niri session exits.
              # Never reached during normal operation (initial_session wins).
              default_session = {
                command = "${pkgs.greetd}/bin/agreety";
                user = "greeter";
              };
              initial_session = {
                command = "${pkgs.niri}/bin/niri-session";
                user = inputs.self.lib.user;
              };
            };
          };

          services.dbus.implementation = lib.mkForce "dbus";

          # wm/niri home module auto-imports via home/profiles/shared.nix from hostConfig.wms
          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../home/profiles/m920q/niri.nix.specialisation
          ];
        };
      };

      wifi = {
        wms = null;
        profile = "server-efficiency";
        extraConfig = {
          pkgs,
          config,
          ...
        }: {
          systemd.services.deploy-iwd-wifi = {
            wantedBy = ["multi-user.target"];
            after = ["sops-nix.service"];
            before = ["iwd.service"];
            serviceConfig = {
              Type = "oneshot";
              ExecStart =
                "${pkgs.coreutils}/bin/install -m 0600 -o root -g root "
                + "${config.sops.templates."wifi/iwd".path} "
                + "/var/lib/iwd/PrettyFlyForAWiFi.psk";
            };
          };
        };
      };
    };
  };

  services.vitals = {
    enable = true;
    headless = true;
  };

  environment.systemPackages = with pkgs;
    [
      wakeonlan # Send magic packets to wake desktop from homelab
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
    # Serial console on the second UART (ttyS0 at 115200 baud). Gives an
    # out-of-band text console via AMT Serial-over-LAN even when systemd drops
    # to emergency/rescue mode and all network services are down. tty1 stays
    # primary on the local display.
    "console=ttyS0,115200n8"
  ];

  # A getty on the AMT serial console: recover a text login via Serial-over-LAN
  # with no monitor attached. Works independently of the GUI/tty1 config.
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = ["getty.target"];
    unitConfig.After = ["dev-ttyS0.device"];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

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
  ];

  networking.wireless.iwd.enable = true;

  boot.kernelModules = ["vkms"];

  # KillMode "mixed": SIGTERM to the main process, SIGKILL to the remaining
  # cgroup. Avoids the ~90s stop timeout during specialisation mode switches
  # while still ensuring the whole cgroup (workers) is torn down.
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
      extraConfig = ''
        RateLimitIntervalSec=30s
        RateLimitBurst=100
        SystemMaxUse=500M
        SystemMaxFileSize=50M
        Compress=yes
        ForwardToSyslog=no
      '';
    };

    pipewire.wireplumber.extraConfig."10-disable-bluez" = {
      "monitor.bluez.properties" = {
        "bluez5.enabled" = false;
      };
    };
  };

  # Bluetooth is unused on this host; disable to suppress wireplumber bluez5 warnings
  hardware.bluetooth.enable = lib.mkForce false;

  # Headless rendering claims tty1 directly (airplay kmssink); a getty login
  # prompt on the projector serves nobody and leaks hostname and username to
  # the room. Disabling the instance keeps emergency shells (sulogin via
  # rescue/emergency targets) and ssh access unaffected. A bare Restart=no
  # here is not enough: getty@tty1 still starts from getty.target at boot.
  systemd.units."getty@tty1" = lib.mkIf (!config.hostConfig.isGui) {
    enable = false;
  };

  # Root ownership signals tmpfiles that subdirectory ownership transitions are intentional
  systemd.tmpfiles.rules = [
    "d /per/mnt/data/Media 0755 root root -"
  ];

  hardware.profiles.powerManagement = {
    enable = true;
    lanInterface = "eno1";
    suppressLeds = true;
    # thermald >= 2.5.12 refuses to start on non-mobile ACPI platform profiles
    # (upstream intel/thermal_daemon#562); kernel TCC throttling and RAPL limits
    # provide thermal protection on this desktop.
    intelCpuThermals = false;
  };

  systemd.timers.zfs-snapshot-frequent.enable = lib.mkForce false;

  services.smartd = {
    enable = true;
    # Runs short self-tests daily at 2am, long tests weekly on Sunday at 4am
    defaults.autodetected = "-a -s (S/../.././02|L/../../7/04) -m <nomailer> -M exec ${ntfySmartNotify}";
    notifications.wall.enable = false;
    notifications.mail.enable = false;
  };

  modules.system.mediaClient.enable = true;

  # AirPlay receiver runs headless (kmssink, udev-triggered) so casting from
  # the MacBook works without booting into the niri specialisation; the niri
  # leaf overrides the mode to gui above.
  modules.system.airplayReceiver.enable = true;

  hardware.steam-hardware.enable = true;

  # Headless homelab: if systemd ever lands in emergency/rescue, auto-reboot
  # after a grace period so systemd-boot boot counting rolls back to a working
  # generation instead of idling locked out of SSH/Tailscale/network. A human
  # at the console can cancel with: systemctl stop emergency-deadman
  system.emergency = {
    enable = true;
    deadmanAutoRecover = true;
  };

  modules.system = {
    # GUI mode is opt-in: casting is handled headless by airplay-receiver, so
    # enter niri via the boot-menu specialisation entry or manually:
    #   echo niri > /run/m920q-desired-mode && systemctl start m920q-mode-switch
    m920q.enable = true;
    stylix-catppuccin.enable = true;
    containers.enable = true;
    # Pull-based GitOps: converge to main automatically. m920q hosts the ntfy
    # endpoint itself, so alerts go through the loopback address.
    comin = {
      enable = true;
      alertNtfyUrl = "http://127.0.0.1:2586/homelab-alerts";
      # Development host: push described local work into PRs before the next
      # poll can converge over it.
      autoPush.enable = true;
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
        autoRebootForKernel = true;
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

  modules.system.homelab = {
    adguardhome.enable = true;
    backup = {
      enable = true;
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
      dataPath = "/per/mnt/data/Media/Pictures";
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
    navidrome = {
      enable = true;
      openFirewall = true;
    };
    nextcloud = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      dataPath = "/per/mnt/data/nextcloud";
    };
    caddyProxy = {
      enable = true;
      tailnetDomain = "m920q.tailf2f0ca.ts.net";
    };
    homepage.enable = true;
    ntfy.enable = true;
    remoteControl = {
      enable = true;
      # Tailscale Serve replaced by Caddy reverse proxy; caddyProxy handles
      # the HTTPS endpoint at remote-control.m920q.tailf2f0ca.ts.net.
      enableTailscaleServe = false;
    };
    samba.enable = true;
    tailscale = {
      enable = true;
      # Tailscale SSH for phone/Termux access: tailscaled authenticates
      # tailnet clients by device identity, no key management needed.
      openSSH = true;
      advertiseRoutes = ["192.168.178.0/24"];
      udpGROInterface = "eno1";
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
