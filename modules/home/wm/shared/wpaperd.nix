sessionTarget: {config, ...}: {
  config = {
    services.wpaperd = {
      enable = true;
      settings = {
        # Primary monitor configuration
        eDP-1 = {
          path = config.wallpapers.wallpaperPath or "${config.home.homeDirectory}/.config/wallpapers";
          apply-shadow = true;
          duration = "30m"; # Change wallpaper every 30 minutes
          mode = "center"; # center, stretch, fit, tile
          sorting = "random";
        };

        # Fallback for any other monitors
        default = {
          path = config.wallpapers.wallpaperPath or "${config.home.homeDirectory}/.config/wallpapers";
          apply-shadow = true;
          duration = "30m";
          mode = "center";
          sorting = "random";
        };
      };
    };

    # Ensure the service starts with the session
    systemd.user.services.wpaperd = {
      Unit.After = [sessionTarget];
      Install.WantedBy = [sessionTarget];
    };
  };
}
