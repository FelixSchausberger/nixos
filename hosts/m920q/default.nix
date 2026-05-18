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

  hdmiDetectScript = pkgs.writeShellScript "m920q-hdmi-detect" ''
    set -euo pipefail

    hdmi_status_files=(/sys/class/drm/*-HDMI-A-*/status)
    if (( ''${#hdmi_status_files[@]} == 0 )); then
      exit 0
    fi

    if grep -qs connected "''${hdmi_status_files[@]}"; then
      echo "niri" > /run/m920q-hdmi-state
    else
      echo "headless" > /run/m920q-hdmi-state
    fi

    exec /run/current-system/sw/bin/systemctl start m920q-mode-switch.timer
  '';

  modeSwitchScript = pkgs.writeShellScript "m920q-mode-switch" ''
    set -euo pipefail

    exec 9>/run/m920q-mode-switch.lock
    /run/current-system/sw/bin/flock -n 9 || exit 0

    profile=/nix/var/nix/profiles/system
    headless_switch="$profile/bin/switch-to-configuration"
    gui_switch="$profile/specialisation/niri/bin/switch-to-configuration"
    hm_service="home-manager-${user}.service"
    mode_file=/run/m920q-current-mode
    state_file=/run/m920q-hdmi-state

    timeout 30 bash -c 'until /run/current-system/sw/bin/nix-daemon --version >/dev/null 2>&1; do sleep 0.5; done' 2>/dev/null || true

    if [[ ! -f "$state_file" ]]; then
      exit 0
    fi

    desired_mode=$(cat "$state_file")

    current_mode=""
    if [[ -f "$mode_file" ]]; then
      current_mode=$(cat "$mode_file")
    fi

    if [[ "$current_mode" == "$desired_mode" ]]; then
      exit 0
    fi

    if [[ "$current_mode" == "niri" ]]; then
      sudo -u ${user} DISPLAY= WAYLAND_DISPLAY= XDG_RUNTIME_DIR=/run/user/1000 /run/current-system/sw/bin/niri msg quit 2>/dev/null || true
      timeout 5 bash -c 'while /run/current-system/sw/bin/systemctl --user -M ${user}@ is-active niri.service 2>/dev/null; do sleep 0.5; done' || true
    fi

    if [[ "$desired_mode" == "niri" ]]; then
      "$gui_switch" test
    else
      "$headless_switch" test
    fi

    echo "$desired_mode" > "$mode_file"

    systemctl restart "$hm_service"
    systemctl restart getty@tty1.service

    if [[ "$desired_mode" == "niri" ]]; then
      systemctl start bluetooth.service
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

  services.vitals.enable = true;
  services.vitals.headless = true;

  environment.systemPackages = lib.mkDefault (
    with pkgs; [
      powertop # CPU C-state residency, wakeups/sec, power estimation
      iotop # Per-process disk IO monitoring
      htop # Process monitoring (already included via btop but useful)
      lm_sensors # Temperature, voltage, fan speed via hwmon
    ]
  );

  boot.kernelParams = lib.mkAfter [
    "zfs.zfs_arc_max=8589934592"
    "zfs.zfs_arc_min=536870912"
  ];

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
        linkConfig.RequiredForOnline = "routable";
        networkConfig.DHCP = "no";
        address = ["192.168.178.2/24"];
        gateway = ["192.168.178.1"];
        dns = [
          "127.0.0.1"
          "192.168.178.1"
        ];
        domains = ["local"];
      };
    };
    wait-online = {
      extraArgs = ["--interface=eno1"];
    };
  };

  networking.wireless.iwd.enable = true;

  boot.kernelModules = ["vkms"];

  systemd.services.m920q-hdmi-detect = {
    description = "Detect HDMI hotplug and update mode state";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = hdmiDetectScript;
    };
  };

  systemd.timers.m920q-mode-switch = {
    description = "Debounced M920q mode switch after HDMI hotplug";
    wantedBy = ["multi-user.target"];
    timerConfig = {
      OnActiveSec = 10;
      AccuracySec = "5s";
    };
  };

  systemd.services.m920q-mode-switch = {
    description = "Switch M920q mode from HDMI hotplug (debounced)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = modeSwitchScript;
      TimeoutStartSec = 120;
    };
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", ENV{DEVTYPE}=="drm_minor", RUN+="${pkgs.systemd}/bin/systemctl start m920q-hdmi-detect.service"
  '';

  systemd.services.nix-daemon.serviceConfig.KillMode = lib.mkForce "control-group";

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
    getty.autologinUser = inputs.self.lib.user;

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
  };

  systemd.services."getty@tty1" = {
    unitConfig = {
      StartLimitBurst = 3;
      StartLimitIntervalSec = 60;
    };
    serviceConfig = {
      Restart = "on-success";
    };
  };

  hardware.profiles.powerManagement = {
    enable = true;
    lanInterface = "eno1";
    suppressLeds = true;
  };

  systemd.timers.zfs-snapshot-frequent.enable = lib.mkForce false;

  modules.system.mediaClient.enable = true;

  hardware.steam-hardware.enable = true;

  modules.system = {
    stylix-catppuccin.enable = true;
    containers.enable = true;
    maintenance = {
      enable = true;
      autoUpdate.enable = false;
      monitoring = {
        enable = true;
        alerts = true;
      };
    };
  };

  boot.zfs.extraPools = [
    "dpool"
    "bpool"
  ];

  fileSystems = {
    "/per/mnt/data" = {
      device = "dpool/data";
      fsType = "zfs";
      neededForBoot = false;
    };
    "/per/mnt/backup" = {
      device = "bpool/backup";
      fsType = "zfs";
      neededForBoot = false;
    };
  };

  modules.system.homelab = {
    adguardhome.enable = true;
    backup.enable = true;
    samba.enable = true;
    immich = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      dataPath = "/per/mnt/data/Media/Pictures";
    };
    tailscale = {
      enable = true;
      advertiseRoutes = ["192.168.178.0/24"];
      udpGROInterface = "eno1";
    };

    monitoring.enable = true;

    ssh.enable = true;
  };
}
