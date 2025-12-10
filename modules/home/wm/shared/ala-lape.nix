{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.ala-lape.homeManagerModules.default
  ];

  config = {
    services.ala-lape = {
      enable = false; # Disabled by default, enable per-host
      package = inputs.ala-lape.packages.${pkgs.hostPlatform.system}.default;
      config = {
        inhibitors = {
          notifications = {
            # Uses mako/wired for notifications
            # Manual configuration required based on notification daemon
            # wired.enable = true;
          };
        };

        limits = {
          poll_frequency = "30s";
          activity_timeout = "30s";
          event_threshold = 6;
        };

        # Example gamepad configuration - customize as needed
        gamepad = [
          {name = "X-Box 360";}
          {name = "PlayStation";}
        ];

        # Example process-based inhibition - customize as needed
        process = [
          {name = "mpv";}
          {name = "vlc";}
          {name = "firefox";}
        ];

        power = {
          when = "WhilePluggedIn"; # Options: Always, WhilePluggedIn, Never
        };
      };
    };
  };
}
