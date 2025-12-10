{
  lib,
  config,
  ...
}: let
  cfg = config.hardware.profiles.battery;
in {
  options.hardware.profiles.battery = {
    enable = lib.mkEnableOption "Unified battery management with automatic detection";

    jolt = {
      enable = lib.mkEnableOption "jolt battery monitor" // {default = true;};
    };

    tlp = {
      enable = lib.mkEnableOption "TLP advanced power management" // {default = true;};
      settings = lib.mkOption {
        type = lib.types.attrs;
        default = {
          START_CHARGE_THRESH_BAT0 = 40;
          STOP_CHARGE_THRESH_BAT0 = 80;
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        };
      };
    };

    chargeThresholds = {
      enable = lib.mkEnableOption "Battery charge limits for longevity" // {default = true;};
    };
  };

  config = lib.mkIf cfg.enable {
    # TODO: jolt disabled due to upstream build issue
    # See: https://github.com/jordond/jolt/issues/XXX
    # environment.systemPackages = lib.optionals cfg.jolt.enable [pkgs.jolt];

    # systemd.services.jolt-daemon = lib.mkIf cfg.jolt.enable {
    #   description = "Jolt battery monitoring daemon";
    #   unitConfig.ConditionPathExists = "/sys/class/power_supply/BAT0";
    #   serviceConfig = {
    #     ExecStart = "${pkgs.jolt}/bin/jolt daemon start";
    #     Type = "forking";
    #     Restart = "on-failure";
    #   };
    #   wantedBy = ["multi-user.target"];
    # };

    services.tlp = lib.mkIf cfg.tlp.enable {
      enable = true;
      settings = cfg.tlp.settings // {};
    };

    services.upower.enable = true;

    systemd.tmpfiles.rules = lib.optionals cfg.chargeThresholds.enable [
      "w /sys/class/power_supply/BAT0/charge_control_start_threshold - - - - ${toString cfg.tlp.settings.START_CHARGE_THRESH_BAT0}"
      "w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - ${toString cfg.tlp.settings.STOP_CHARGE_THRESH_BAT0}"
    ];

    powerManagement.powertop.enable = lib.mkDefault true;
  };
}
