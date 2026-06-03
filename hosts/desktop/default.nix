# Desktop workstation host: AMD gaming/rendering machine with Niri as default WM.
# Uses DP hotplug to switch between home (physical monitor) and away (virtual display) modes.
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

  dpDetectScript = pkgs.writeShellScript "desktop-dp-detect" ''
    set -euo pipefail

    dp_status_files=(/sys/class/drm/*-DP-*/status)
    if (( ''${#dp_status_files[@]} == 0 )); then
      echo "away" > /run/desktop-dp-state
      exec /run/current-system/sw/bin/systemctl restart desktop-mode-switch.timer
    fi

    if grep -qs connected "''${dp_status_files[@]}"; then
      echo "home" > /run/desktop-dp-state
    else
      echo "away" > /run/desktop-dp-state
    fi

    exec /run/current-system/sw/bin/systemctl restart desktop-mode-switch.timer
  '';

  modeSwitchScript = pkgs.writeShellScript "desktop-mode-switch" ''
    set -euo pipefail

    exec 9>/run/desktop-mode-switch.lock
    /run/current-system/sw/bin/flock -n 9 || exit 0

    profile=/nix/var/nix/profiles/system
    away_switch="$profile/bin/switch-to-configuration"
    home_switch="$profile/specialisation/home/bin/switch-to-configuration"
    hm_service="home-manager-${user}.service"
    mode_file=/run/desktop-current-mode
    state_file=/run/desktop-dp-state

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

    if [[ "$desired_mode" == "home" ]]; then
      "$home_switch" test || true
    else
      "$away_switch" test || true
    fi

    echo "$desired_mode" > "$mode_file"

    systemctl restart "$hm_service"
    systemctl restart greetd.service
  '';

  desktopDisplayModeScript = pkgs.writeShellScriptBin "desktop-display-mode" ''
    set -euo pipefail

    profile=/nix/var/nix/profiles/system
    hm_service="home-manager-${user}.service"

    case "''${1:-}" in
      away)
        "$profile/bin/switch-to-configuration" test
        echo away > /run/desktop-current-mode
        systemctl restart "$hm_service"
        systemctl restart greetd.service
        ;;
      home)
        "$profile/specialisation/home/bin/switch-to-configuration" test
        echo home > /run/desktop-current-mode
        systemctl restart "$hm_service"
        systemctl restart greetd.service
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

  # Niri home profile loaded at parent level (niri is the default WM)
  home-manager.users.${inputs.self.lib.user}.imports = [
    ../../home/profiles/desktop/niri.nix.specialisation
  ];

  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;

    specialisations = {
      home = {
        wms = ["niri"];
        profile = "default";
        extraConfig = {
          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../home/profiles/desktop/niri-home.nix
          ];
          modules.system.sunshine.enable = lib.mkForce false;
        };
      };
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

  systemd.services.desktop-dp-detect = {
    description = "Detect DP hotplug and update desktop mode state";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = dpDetectScript;
    };
  };

  systemd.timers.desktop-mode-switch = {
    description = "Debounced desktop mode switch after DP hotplug";
    wantedBy = ["multi-user.target"];
    timerConfig = {
      OnActiveSec = 10;
      AccuracySec = "5s";
    };
  };

  systemd.services.desktop-mode-switch = {
    description = "Switch desktop mode from DP hotplug (debounced)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = modeSwitchScript;
      TimeoutStartSec = 120;
    };
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", ENV{DEVTYPE}=="drm_minor", RUN+="${pkgs.systemd}/bin/systemctl start desktop-dp-detect.service"
  '';

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
