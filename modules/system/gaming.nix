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

    # xpadneo: advanced Xbox One/Series wireless driver. It is a kernel module,
    # so it takes effect only through the system kernel (extraModulePackages
    # plus kernelModules) and must be built for boot.kernelPackages; a
    # home.packages entry would install the .ko into a user profile where
    # nothing loads it. hid_xpadneo replaces hid-generic for Xbox pads connected
    # locally or through the Steam Controller puck's Bluetooth side.
    boot.extraModulePackages = [config.boot.kernelPackages.xpadneo];
    boot.kernelModules = ["hid_xpadneo"];

    # Required for gamemoderun to reach the daemon; without it optimizations
    # are silently skipped (GPU tuning also needs the accept-responsibility
    # path enabled in settings below).
    users.users.${config.hostConfig.user}.extraGroups = ["gamemode"];

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
