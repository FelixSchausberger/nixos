{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.hardware.profiles.powerManagement;
in {
  options.hardware.profiles.powerManagement = {
    enable = lib.mkEnableOption "power management for 24/7 homelab servers (auto-cpufreq, powertop, WoL, LED suppression)";

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
      description = "Wired ethernet interface for Wake-on-LAN";
    };

    suppressLeds = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable front panel LEDs to reduce light/noise in bedroom";
    };
  };

  config = lib.mkIf cfg.enable {
    # auto-cpufreq dynamically scales CPU frequency based on load.
    services.auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "off";
        };
        charge.threshold = 80;
        performance = {
          governor = "powersave";
          turbo = "auto";
        };
        balanced = {
          governor = "powersave";
          turbo = "auto";
        };
      };
    };

    # Enable runtime power tuning defaults.
    powerManagement.powertop.enable = lib.mkDefault true;

    # Keep thermal throttling policy active for long-running workloads.
    services.thermald.enable = true;

    boot.kernelParams = [
      # Let cpufreq-based tools manage frequency policy.
      "intel_pstate=passive"

      # Limit deep idle states for predictable wake latency.
      "processor.max_cstate=6"

      # Keep intel_idle aligned with the global C-state cap.
      "intel_idle.max_cstate=6"
    ];

    # Allow waking the host via magic packet.
    systemd.services.wol-lan = {
      description = "Wake-on-LAN on ${cfg.lanInterface}";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ethtool}/bin/ethtool -s ${cfg.lanInterface} wol g";
      };
    };

    # Disable chassis LED triggers for quieter bedroom operation.
    systemd.tmpfiles.rules = lib.optionals cfg.suppressLeds [
      "w /sys/class/leds/*/trigger - - - - none"
    ];

    environment.systemPackages = with pkgs; [
      powertop
      ethtool
      intel-gpu-tools
    ];
  };
}
