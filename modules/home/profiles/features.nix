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
        type = lib.types.listOf (lib.types.enum ["rust" "python" "go" "nix" "javascript"]);
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
        type = lib.types.listOf (lib.types.enum ["steam" "lutris" "emulation" "minecraft"]);
        default = ["steam"];
        description = "Gaming platforms to support";
      };
    };

    # Media features
    media = {
      enable = lib.mkEnableOption "media applications and services";
      services = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["music"]);
        default = [];
        description = "Media services to include";
      };
    };

    # Productivity features
    productivity = {
      enable = lib.mkEnableOption "productivity applications";
      tools = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["notes" "tasks"]);
        default = [];
        description = "Productivity tools to include";
      };
    };

    # Communication features
    communication = {
      enable = lib.mkEnableOption "communication applications";
      protocols = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["matrix"]);
        default = [];
        description = "Communication protocols to support";
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
            cargo-watch # Auto-rebuild on source changes (used by zellij rust layout)
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
          ]
          # Runtime only: the TypeScript/JavaScript LSP ships via the helix
          # languages module once development is enabled.
          ++ lib.optionals (lib.elem "javascript" config.features.development.languages) [
            nodejs
          ]
      ))

      # Creative packages
      (lib.mkIf config.features.creative.enable (
        with pkgs;
          lib.optionals (lib.elem "image" config.features.creative.tools) [
            krita
            inkscape
            gimp # The GNU Image Manipulation Program
          ]
          ++ lib.optionals (lib.elem "video" config.features.creative.tools) [
            ffmpeg
          ]
          ++ lib.optionals (lib.elem "3d" config.features.creative.tools) [
            blender
            freecad # 3D CAD software
            prusa-slicer # G-code generator for 3D printer
          ]
      ))

      # Gaming packages
      (lib.mkIf config.features.gaming.enable (
        with pkgs;
          lib.optionals (lib.elem "steam" config.features.gaming.platforms) [
            steam # Gaming platform
          ]
          ++ lib.optionals (lib.elem "lutris" config.features.gaming.platforms) [
            lutris
          ]
          ++ lib.optionals (lib.elem "emulation" config.features.gaming.platforms) [
            retroarch
            dolphin-emu
          ]
          ++ lib.optionals (lib.elem "minecraft" config.features.gaming.platforms) [
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.quantumlauncher
          ]
      ))

      # Media packages
      (lib.mkIf config.features.media.enable (
        with pkgs;
          lib.optionals (lib.elem "music" config.features.media.services) [
            # Spicetify is handled by gui/spicetify.nix (self-gated)
          ]
      ))

      # Productivity packages
      (lib.mkIf config.features.productivity.enable (
        with pkgs;
          lib.optionals (lib.elem "notes" config.features.productivity.tools) [
            # Obsidian is handled by gui/obsidian.nix (self-gated)
          ]
          ++ lib.optionals (lib.elem "tasks" config.features.productivity.tools) [
            planify # Task manager with Todoist support
            noto-fonts-emoji-blob-bin # Font needed for planify
          ]
      ))

      # Communication packages
      (lib.mkIf config.features.communication.enable (
        with pkgs;
          lib.optionals (lib.elem "matrix" config.features.communication.protocols) [
            fractal # Matrix group messaging app
          ]
      ))
    ];

    # Font configuration for planify
    fonts.fontconfig.enable = lib.mkIf config.features.productivity.enable true;

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
