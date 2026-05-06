# ThinkCentre M920q dual-role host: headless homelab server with optional HDMI-triggered GUI mode.
# Prioritizes low idle power while keeping a Niri specialisation available for local media use.
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  hostLib = import ../lib.nix;
  hostName = "m920q";
  hostInfo = inputs.self.lib.hosts.${hostName};
  inherit (inputs.self.lib) user;
  modeSwitchScript = pkgs.writeShellScript "m920q-mode-switch" ''
    set -euo pipefail

    profile=/nix/var/nix/profiles/system
    headless_switch="$profile/bin/switch-to-configuration"
    gui_switch="$profile/specialisation/niri/bin/switch-to-configuration"
    hm_service="home-manager-${user}.service"

    if grep -qs connected /sys/class/drm/*-HDMI-A-*/status; then
      "$gui_switch" test
      systemctl restart "$hm_service"
      systemctl restart getty@tty1.service
      systemctl start bluetooth.service
    else
      "$headless_switch" test
      systemctl restart "$hm_service"
      systemctl restart getty@tty1.service
    fi
  '';
in {
  imports =
    [
      ./disko.nix
      ../shared-tui.nix
      ../boot-zfs.nix
      ../../modules/system/specialisations.nix
      ../../modules/system/homelab
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
    # ThinkCentre M920q dual-role: 24/7 homelab server + near-silent bedroom media client.
    # server-efficiency profile: powersave governor, deep C-states, reduced wakeups,
    # no turbo spikes, minimal fan activity. Switch to niri specialisation for GUI use.
    performanceProfile = "server-efficiency";

    specialisations = {
      niri = {
        wms = ["niri"];
        profile = "default";
        extraConfig = {pkgs, ...}: {
          imports = [../../modules/system/wm/niri.nix];

          modules.system.airplayReceiver.enable = true;

          hostConfig.isGui = lib.mkForce true;

          hardware.graphics = {
            enable = true;
            enable32Bit = true;
          };

          programs.niri = {
            enable = lib.mkForce true;
            package = pkgs.niri;
          };
          programs.uwsm = {
            enable = lib.mkForce true;
            waylandCompositors.niri = {
              prettyName = "Niri";
              comment = "Scrollable tiling Wayland compositor";
              binPath = "${pkgs.niri}/bin/niri --session";
            };
          };

          services.dbus.implementation = lib.mkForce "dbus";
          services.getty.autologinUser = inputs.self.lib.user;

          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../modules/home/wm/niri
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

  # Vitals health monitoring daemon
  services.vitals.enable = true;
  services.vitals.headless = true;

  # Observability packages: verify power efficiency and system health.
  environment.systemPackages = lib.mkDefault (
    with pkgs; [
      powertop # CPU C-state residency, wakeups/sec, power estimation
      iotop # Per-process disk IO monitoring
      htop # Process monitoring (already included via btop but useful)
      lm_sensors # Temperature, voltage, fan speed via hwmon
    ]
  );

  # ZFS snapshot policy override for server-efficiency:
  # Disable frequent (15-min) snapshots — unnecessary wakeups for a server
  # that already has hourly/daily snapshots for recovery.
  # Clamp minimum ARC to 512MB — small floor for a headless server.
  boot.kernelParams = lib.mkAfter [
    "zfs.zfs_arc_max=8589934592"
    "zfs.zfs_arc_min=536870912"
  ];

  # x86_64-linux; set here since hardware-configuration.nix is generated post-install
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # ThinkCentre M920q: Intel i7-8700T, Intel UHD 630 iGPU
  # modesetting covers headless operation; full graphics stack added by niri specialisation
  services.xserver.videoDrivers = lib.mkDefault [
    "modesetting"
    "intel"
  ];

  # Unique ZFS host identifier — required per machine, must not match any other host
  networking.hostId = lib.mkForce "b580701b";

  # Static LAN: systemd-networkd with fixed IP for reliability and lower overhead than NetworkManager.
  # WiFi (iwd) remains available via 'iwctl' for manual connections when needed.
  # NetworkManager is replaced entirely — eno1 gets a static lease from the router DHCP,
  # which reserves 192.168.178.2 for this MAC, so the IP is effectively static.
  networking.useNetworkd = true;
  networking.networkmanager.enable = lib.mkForce false;

  systemd.network = {
    enable = true;
    networks = {
      "10-eno1" = {
        matchConfig.Name = "eno1";
        linkConfig.RequiredForOnline = "routable";
        networkConfig.DHCP = "no";
        address = ["192.168.178.2/24"];
        gateway = ["192.168.178.1"];
        # DNS: AdGuardHome (local) primary, router fallback
        dns = [
          "127.0.0.1"
          "192.168.178.1"
        ];
        domains = ["local"];
      };
    };
    # Wait only for the wired interface to come up — don't block boot on WiFi
    wait-online = {
      extraArgs = ["--interface=eno1"];
    };
  };

  # iwd (wireless daemon) available for manual WiFi via 'iwctl'.
  # Standalone mode — not managed by NetworkManager (which is disabled).
  # Activate on demand: 'iwctl' will start the daemon automatically.
  networking.wireless.iwd.enable = true;

  # vkms provides a virtual display adapter for the niri specialisation's headless remote desktop.
  # Loaded unconditionally so `just activate niri` works without a reboot.
  boot.kernelModules = ["vkms"];

  # Auto-switch runtime mode based on projector HDMI hotplug events.
  # Any connected HDMI sink activates niri; all disconnected reverts to headless.
  systemd.services.m920q-mode-switch = {
    description = "Switch M920q mode from HDMI hotplug";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = modeSwitchScript;
    };
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", KERNEL=="card*-HDMI-A-*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="m920q-mode-switch.service"
  '';

  # Allow rebuilds from inside zellij by lazily detaching the persistence bind mount
  # when activation stops/restarts mount units.
  systemd.units."home-${user}-.cache-zellij.mount" = {
    overrideStrategy = lib.mkForce "asDropin";
    text = lib.mkForce ''
      [Mount]
      LazyUnmount=yes
    '';
  };

  fileSystems."/per".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  # Disable services not applicable to server hardware
  services = {
    # fwupd: useful for real hardware (BIOS, NIC firmware); keep enabled
    # geoclue2: location services have no purpose on a headless server
    geoclue2.enable = lib.mkForce false;

    # session/default.nix switches dbus to broker when UWSM is enabled.
    # Force dbus on the parent config so live activation never attempts a dbus swap.
    dbus.implementation = lib.mkForce "dbus";

    # journald: rate-limit to reduce CPU wakeups from excessive logging.
    # 30-second interval and 100-burst limit is conservative for a quiet server.
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
  };

  # Power management: auto-cpufreq + powertop autotune for deep C-states and low idle power.
  # See modules/system/hardware/power-management.nix for full configuration.
  hardware.profiles.powerManagement = {
    enable = true;
    lanInterface = "eno1";
    suppressLeds = true;
  };

  # Disable 15-minute snapshots to avoid frequent wakeups on a 24/7 efficiency-focused host.
  # Hourly/daily/weekly snapshots remain enabled for recovery.
  systemd.timers.zfs-snapshot-frequent.enable = lib.mkForce false;

  # Media client: VAAPI hardware decode + Moonlight streaming client.
  # VAAPI allows efficient video playback via Intel UHD 630 iGPU.
  # Moonlight connects to Sunshine server on the desktop host.
  modules.system.mediaClient.enable = true;

  # Host-specific sops secrets — expanded when monitoring/tailscale-auth are enabled

  modules.system = {
    stylix-catppuccin.enable = true;
    containers.enable = true;
    maintenance = {
      enable = true;
      # Manual updates preferred for a production server
      autoUpdate.enable = false;
      monitoring = {
        enable = true;
        alerts = true;
      };
    };
  };

  modules.system.homelab = {
    adguardhome.enable = true;

    # Requires data disk (dpool) — enable after 2TB drive is installed
    samba.enable = false;
    immich.enable = false;

    tailscale = {
      enable = true;
      # authKeyFile omitted — run `sudo tailscale up` after first boot to authenticate
      advertiseRoutes = ["192.168.178.0/24"];
      udpGROInterface = "eno1";
    };

    # Requires real domain names pointing to 116.204.198.109 — enable after DNS is configured
    caddy.enable = false;

    rustdesk = {
      enable = true;
      # Tailscale IP — advertised by hbbs so remote clients know where to reach hbbr
      relayAddress = "100.105.37.12";
    };

    # Requires grafana secrets
    monitoring.enable = true;

    ssh.enable = true;
  };
}
