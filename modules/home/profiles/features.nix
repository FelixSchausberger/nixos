{
  config,
  lib,
  pkgs,
  ...
}: {
  options.features = {
    # Development features
    development = {
      enable = lib.mkEnableOption "development tools and environments";
      languages = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["rust" "javascript" "python" "go" "nix"]);
        default = [];
        description = "Programming languages to support";
      };
    };
    
    # Creative features  
    creative = {
      enable = lib.mkEnableOption "creative applications and tools";
      tools = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["image" "video" "audio" "3d" "writing"]);
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
    
    # Work features
    work = {
      enable = lib.mkEnableOption "work-specific configurations";
      aws = lib.mkEnableOption "AWS tools and configurations";
      vpn = lib.mkEnableOption "VPN configurations";
    };
    
    # Media features
    media = {
      enable = lib.mkEnableOption "media consumption and management tools";
      streaming = lib.mkEnableOption "streaming services support";
      local = lib.mkEnableOption "local media management";
    };
    
    # Productivity features
    productivity = {
      enable = lib.mkEnableOption "productivity applications";
      office = lib.mkEnableOption "office suite applications";
      notes = lib.mkEnableOption "note-taking applications";
      tasks = lib.mkEnableOption "task management applications";
    };
  };
  
  config = {
    # Development tools
    home.packages = lib.mkMerge [
      # Development packages
      (lib.mkIf config.features.development.enable (with pkgs; 
        # Core development tools (always included)
        [
          git
          pre-commit
          direnv
        ] 
        # Language-specific tools
        ++ lib.optionals (lib.elem "rust" config.features.development.languages) [
          rustup
          rust-analyzer
        ] 
        ++ lib.optionals (lib.elem "javascript" config.features.development.languages) [
          # Remove nodejs packages to avoid conflicts - they're handled by system modules
          # nodePackages dependencies cause nodejs conflicts
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
      ))
      
      # Creative packages (only packages not already in gui/default.nix)
      (lib.mkIf config.features.creative.enable (with pkgs; 
        lib.optionals (lib.elem "image" config.features.creative.tools) [
          # gimp is already in gui/default.nix
          krita
          inkscape
        ] ++ lib.optionals (lib.elem "video" config.features.creative.tools) [
          obs-studio
          kdePackages.kdenlive  # Use Qt 6 version
          ffmpeg
        ] ++ lib.optionals (lib.elem "audio" config.features.creative.tools) [
          audacity
          ardour
        ] ++ lib.optionals (lib.elem "3d" config.features.creative.tools) [
          blender
          # freecad is already in gui/default.nix
        ] ++ lib.optionals (lib.elem "writing" config.features.creative.tools) [
          # obsidian is already in gui/default.nix
          typora
        ]
      ))
      
      # Gaming packages (avoid conflicts with existing steam configs)
      (lib.mkIf config.features.gaming.enable (with pkgs;
        # Don't include steam here - it's handled by hyprland.nix and gui/default.nix
        lib.optionals (lib.elem "lutris" config.features.gaming.platforms) [
          lutris
          wine
        ] ++ lib.optionals (lib.elem "emulation" config.features.gaming.platforms) [
          retroarch
          dolphin-emu
        ]
      ))
      
      # Media packages (only additional ones, not conflicts)
      (lib.mkIf config.features.media.enable (with pkgs; 
        # mpv/vlc are in gui modules and portable host, don't duplicate
        lib.optionals config.features.media.streaming [
          # spotify-player is already in tui/default.nix
        ] ++ lib.optionals config.features.media.local [
          jellyfin-media-player
          plex-media-player
        ]
      ))
      
      # Productivity packages (avoid conflicts with existing)
      (lib.mkIf config.features.productivity.enable (with pkgs;
        lib.optionals config.features.productivity.office [
          # libreoffice is in portable host, don't duplicate
          onlyoffice-bin
        ] ++ lib.optionals config.features.productivity.notes [
          # obsidian is already in gui/default.nix
          logseq
        ] ++ lib.optionals config.features.productivity.tasks [
          # planify is already in gui/default.nix
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
    
    # Creative applications configurations
    xdg.mimeApps.defaultApplications = lib.mkMerge [
      (lib.mkIf (config.features.creative.enable && lib.elem "image" config.features.creative.tools) {
        "image/png" = ["gimp.desktop"];
        "image/jpeg" = ["gimp.desktop"];
        "image/svg+xml" = ["inkscape.desktop"];
      })
      
      (lib.mkIf config.features.media.enable {
        "video/mp4" = ["mpv.desktop"];
        "audio/mpeg" = ["mpv.desktop"];
      })
    ];
  };
}