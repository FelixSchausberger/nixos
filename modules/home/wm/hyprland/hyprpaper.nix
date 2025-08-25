{config, ...}: {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;

      preload = [
        (config.lib.wallpapers.getCurrentWallpaperPath or "${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg")
      ];

      wallpaper = [
        "eDP-1,${config.lib.wallpapers.getCurrentWallpaperPath or "${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg"}"
        ",${config.lib.wallpapers.getCurrentWallpaperPath or "${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg"}"
      ];
    };
  };
}
