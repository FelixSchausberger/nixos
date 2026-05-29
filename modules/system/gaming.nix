{
  config,
  lib,
  ...
}: {
  imports = [./steam.nix];

  options.modules.system.gaming = {
    enable = lib.mkEnableOption "gaming performance profile and Steam integration";
  };

  config = lib.mkIf config.modules.system.gaming.enable {
    assertions = [
      {
        assertion = config.hostConfig.isGui;
        message = "modules.system.gaming.enable requires hostConfig.isGui = true";
      }
    ];

    modules.system.steam.enable = true;

    # Security configuration for better gaming performance
    security.pam.loginLimits = [
      # Real-time scheduling for better audio/gaming performance
      {
        domain = "@users";
        item = "rtprio";
        type = "-";
        value = "1";
      }
      {
        domain = "@users";
        item = "nice";
        type = "-";
        value = "-11";
      }
      {
        domain = "@users";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
    ];

    # GameMode for automatic game optimizations
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
          ioprio = 4;
          inhibit_screensaver = 1;
        };

        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };
  };
}
