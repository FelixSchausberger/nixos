sessionTarget: {
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.ala-lape.homeManagerModules.default
  ];

  config = {
    services.ala-lape = {
      enable = true;
      package = inputs.ala-lape.packages.${pkgs.system}.default;
      config = {
        inhibitors = {
          notifications = {
            # TODO: Configure based on notification daemon used
            # swaync.enable = true;
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

    # Ensure the service starts with the session
    systemd.user.services.ala-lape = {
      Unit.After = [sessionTarget];
      Install.WantedBy = [sessionTarget];
    };
  };
}
