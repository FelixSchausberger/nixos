{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  options.features = {
    # Development features
    development = {
      enable = lib.mkEnableOption "development tools and environments";
      languages = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["rust" "python" "go" "nix"]);
        default = [];
        description = "Programming languages to support";
      };
    };

    # Creative features
    creative = {
      enable = lib.mkEnableOption "creative applications and tools";
      tools = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["image" "video" "3d"]);
        default = [];
        description = "Creative tool categories to include";
      };
    };

    # Gaming features
    gaming = {
      enable = lib.mkEnableOption "gaming applications and tools";
      platforms = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["steam" "lutris" "emulation"]);
        default = ["steam"];
        description = "Gaming platforms to support";
      };
    };
  };

  config = {
    # Development tools
    home.packages = lib.mkMerge [
      # Development packages
      (lib.mkIf config.features.development.enable (
        with pkgs;
        # Core development tools (always included)
          [
            git
            direnv
          ]
          # Language-specific tools
          ++ lib.optionals (lib.elem "rust" config.features.development.languages) [
            rustup
            bugstalker # Modern Rust debugger with async support
          ]
          ++ lib.optionals (lib.elem "python" config.features.development.languages) [
            python3
            python3Packages.pip
            poetry
          ]
          ++ lib.optionals (lib.elem "go" config.features.development.languages) [
            go
            gopls
          ]
          ++ lib.optionals (lib.elem "nix" config.features.development.languages) [
            nil
            alejandra
            deadnix
            statix
            inputs.self.packages.${pkgs.hostPlatform.system}.repl
          ]
      ))

      # Creative packages (only packages not already in gui/default.nix)
      (lib.mkIf config.features.creative.enable (
        with pkgs;
          lib.optionals (lib.elem "image" config.features.creative.tools) [
            krita
            inkscape
          ]
          ++ lib.optionals (lib.elem "video" config.features.creative.tools) [
            ffmpeg
          ]
          ++ lib.optionals (lib.elem "3d" config.features.creative.tools) [
            blender
          ]
      ))

      # Gaming packages (avoid conflicts with existing steam configs)
      (lib.mkIf config.features.gaming.enable (
        with pkgs;
        # Don't include steam here - it's handled by hyprland.nix and gui/default.nix
          lib.optionals (lib.elem "lutris" config.features.gaming.platforms) [
            lutris
          ]
          ++ lib.optionals (lib.elem "emulation" config.features.gaming.platforms) [
            retroarch
            dolphin-emu
          ]
      ))
    ];

    # Development shell configurations
    programs = lib.mkIf config.features.development.enable {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      git.enable = lib.mkDefault true;
    };
  };
}
