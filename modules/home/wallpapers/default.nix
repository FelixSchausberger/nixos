{
  config,
  lib,
  ...
}: {
  options.wallpapers = {
    enable = lib.mkEnableOption "centralized wallpaper management" // {default = true;};

    defaultWallpaper = lib.mkOption {
      type = lib.types.str;
      default = "solar-system";
      description = "Default wallpaper name";
      example = "solar-system";
    };

    available = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        solar-system = "solar-system.jpg";
        the-whale = "the-whale.jpg";
        appa = "appa.jpg";
      };
      description = "Available wallpapers mapping name to filename";
    };

    wallpaperPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/wallpapers";
      description = "Path where wallpapers are stored";
    };
  };

  config = let
    cfg = config.wallpapers;
    wallpaperDir = ../wallpapers;
    currentWallpaperFile = cfg.available.${cfg.defaultWallpaper};
    currentWallpaperPath = "${cfg.wallpaperPath}/${currentWallpaperFile}";
  in
    lib.mkIf cfg.enable {
      # Create wallpaper directory structure
      xdg.configFile."wallpapers/.keep".text = "";

      home = {
        # Copy all available wallpapers to user config directory
        file = builtins.listToAttrs (map (wallpaperName: {
          name = "${cfg.wallpaperPath}/${cfg.available.${wallpaperName}}";
          value = {
            source = wallpaperDir + "/${cfg.available.${wallpaperName}}";
          };
        }) (builtins.attrNames cfg.available));

        # Export wallpaper information for other modules to use
        # This creates a way for other modules to access wallpaper paths consistently
        sessionVariables = {
          DEFAULT_WALLPAPER = currentWallpaperPath;
          WALLPAPER_DIR = cfg.wallpaperPath;
        };

        # Convenience functions for wallpaper management
        shellAliases = {
          "wallpaper-list" = "ls -la ${cfg.wallpaperPath}";
          "wallpaper-current" = "echo $DEFAULT_WALLPAPER";
        };
      };

      # Helper functions that other modules can use
      lib.wallpapers = {
        # Get path to a specific wallpaper
        getWallpaperPath = wallpaperName:
          if builtins.hasAttr wallpaperName config.wallpapers.available
          then "${config.wallpapers.wallpaperPath}/${config.wallpapers.available.${wallpaperName}}"
          else builtins.throw "Wallpaper '${wallpaperName}' not found. Available: ${builtins.concatStringsSep ", " (builtins.attrNames config.wallpapers.available)}";

        # Get current default wallpaper path
        getCurrentWallpaperPath = "${config.wallpapers.wallpaperPath}/${config.wallpapers.available.${config.wallpapers.defaultWallpaper}}";

        # Get all wallpaper paths
        getAllWallpaperPaths =
          builtins.mapAttrs (
            _name: filename: "${config.wallpapers.wallpaperPath}/${filename}"
          )
          config.wallpapers.available;
      };
    };
}
