{lib, ...}: {
  # Shared options for all window managers
  options.wm.shared = {
    wallpaper = {
      enable = lib.mkEnableOption "Shared wallpaper management" // {default = true;};

      path = lib.mkOption {
        type = lib.types.str;
        default = "~/.config/wallpapers/solar-system.jpg";
        description = "Path to wallpaper image";
      };

      mode = lib.mkOption {
        type = lib.types.enum ["fill" "fit" "stretch" "center" "tile"];
        default = "fill";
        description = "Wallpaper scaling mode";
      };
    };

    theme = {
      enable = lib.mkEnableOption "Shared WM theme configuration" // {default = true;};

      colorScheme = lib.mkOption {
        type = lib.types.enum ["catppuccin-macchiato" "custom"];
        default = "catppuccin-macchiato";
        description = "Color scheme for window managers";
      };

      borderRadius = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Border radius for windows";
      };

      gaps = {
        inner = lib.mkOption {
          type = lib.types.int;
          default = 4;
          description = "Inner gaps between windows";
        };

        outer = lib.mkOption {
          type = lib.types.int;
          default = 8;
          description = "Outer gaps around workspace edges";
        };
      };

      blur = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable blur effects";
        };

        size = lib.mkOption {
          type = lib.types.int;
          default = 6;
          description = "Blur kernel size";
        };

        passes = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = "Number of blur passes";
        };
      };

      shadows = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable drop shadows";
        };

        range = lib.mkOption {
          type = lib.types.int;
          default = 20;
          description = "Shadow range/size";
        };
      };
    };
  };
}
