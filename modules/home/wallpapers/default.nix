{
  config,
  lib,
  inputs,
  ...
}: let
  # Filenames come from lib/wallpapers.nix so the dashboard background
  # (homepage.nix) resolves the same set without a second hardcoded list.
  inherit (inputs.self.lib) wallpapers;
in {
  imports = [./dynamic.nix];

  options.wallpapers = {
    enable = lib.mkEnableOption "centralized wallpaper management" // {default = true;};

    defaultWallpaper = lib.mkOption {
      type = lib.types.str;
      inherit (wallpapers) default;
      defaultText = lib.literalExpression "inputs.self.lib.wallpapers.default";
      description = "Default wallpaper name";
      example = "solar-system";
    };

    available = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = wallpapers.available;
      defaultText = lib.literalExpression "inputs.self.lib.wallpapers.available";
      description = "Available wallpapers mapping name to filename";
    };

    availableBlurred = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = wallpapers.blurred;
      defaultText = lib.literalExpression "inputs.self.lib.wallpapers.blurred";
      description = "Available blurred wallpapers mapping name to filename";
    };

    wallpaperPath = lib.mkOption {
      type = lib.types.str;
      # The flake source is a store path, so every host resolves the same
      # immutable files; a checkout path would tie the session to one host's
      # installation directory and can change under a running awww.
      default = "${inputs.self}/modules/home/wallpapers";
      defaultText = lib.literalExpression ''"''${inputs.self}/modules/home/wallpapers"'';
      description = "Directory holding the bundled wallpapers";
    };
  };

  config = let
    cfg = config.wallpapers;
    currentWallpaperFile = cfg.available.${cfg.defaultWallpaper};
    currentWallpaperPath = "${cfg.wallpaperPath}/${currentWallpaperFile}";
  in
    lib.mkIf cfg.enable {
      home = {
        # Export wallpaper information for other modules to use.
        sessionVariables = {
          DEFAULT_WALLPAPER = currentWallpaperPath;
          WALLPAPER_DIR = cfg.wallpaperPath;
        };

        shellAliases = {
          "wallpaper-list" = "ls -la ${cfg.wallpaperPath}";
          "wallpaper-current" = "echo $DEFAULT_WALLPAPER";
        };
      };
    };
}
