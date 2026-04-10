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

    availableBlurred = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        solar-system = "solar-system_blurred.jpg";
        the-whale = "the-whale_blurred.jpg";
        appa = "appa_blurred.jpg";
      };
      description = "Available blurred wallpapers mapping name to filename";
    };

    wallpaperPath = lib.mkOption {
      type = lib.types.str;
      # default = "${config.home.homeDirectory}/.config/wallpapers";
      default = "/per/etc/nixos/modules/home/wallpapers";
      description = "Path where wallpapers are stored";
    };
  };

  config = let
    cfg = config.wallpapers;
    currentWallpaperFile = cfg.available.${cfg.defaultWallpaper};
    currentWallpaperPath = "${cfg.wallpaperPath}/${currentWallpaperFile}";
  in
    lib.mkIf cfg.enable {
      home = {
        # No copying needed - wallpapers are accessed directly from repo at /per/etc/nixos/modules/home/wallpapers

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

        # Get path to a specific blurred wallpaper
        getBlurredWallpaperPath = wallpaperName:
          if builtins.hasAttr wallpaperName config.wallpapers.availableBlurred
          then "${config.wallpapers.wallpaperPath}/${config.wallpapers.availableBlurred.${wallpaperName}}"
          else builtins.throw "Blurred wallpaper '${wallpaperName}' not found. Available: ${builtins.concatStringsSep ", " (builtins.attrNames config.wallpapers.availableBlurred)}";

        # Get current default blurred wallpaper path
        getCurrentBlurredWallpaperPath = "${config.wallpapers.wallpaperPath}/${config.wallpapers.availableBlurred.${config.wallpapers.defaultWallpaper}}";

        # Get all blurred wallpaper paths
        getAllBlurredWallpaperPaths =
          builtins.mapAttrs (
            _name: filename: "${config.wallpapers.wallpaperPath}/${filename}"
          )
          config.wallpapers.availableBlurred;
      };
    };
}
