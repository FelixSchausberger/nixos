# Common utility functions for the NixOS configuration
{lib, ...}: rec {
  # Helper to generate user@host format
  getUserHost = user: host: "${user}@${host}";

  # Create consistent profile imports with automatic host detection
  mkProfileImports = hosts: let
    mkProfileForHost = host: {
      name = getUserHost "schausberger" host; # Default user
      value = [
        ../home/profiles/shared.nix # Shared config with dynamic WM
        ../home/profiles/${host} # Host-specific config
      ];
    };
  in
    lib.listToAttrs (map mkProfileForHost hosts);

  # Simplified feature-based module loading
  mkFeatureImports = features:
    lib.flatten [
      (lib.optionals (lib.elem "gui" features) [../modules/home/gui])
      (lib.optionals (lib.elem "gaming" features) [../modules/home/private/gui/steam.nix])
      (lib.optionals (lib.elem "development" features) [../modules/home/private/gui/freecad.nix])
      (lib.optionals (lib.elem "private" features) [../modules/home/private])
    ];

  # Host type detection helpers
  isDesktop = hostName: hostName == "desktop";
  isLaptop = hostName: lib.elem hostName ["surface" "portable"];
  isWork = hostName: hostName == "hp-probook-wsl";

  # Window manager module import helper
  getWmModule = wm:
    if wm == "hyprland"
    then "../modules/system/wm/hyprland.nix"
    else if wm == "cosmic"
    then "../modules/system/wm/cosmic.nix"
    else if wm == "gnome"
    then "../modules/system/wm/gnome.nix"
    else null;

  # Common standardized comments for modules
  moduleComments = {
    # TUI tools
    bat = "A cat clone with syntax highlighting and Git integration";
    eza = "A modern, maintained replacement for ls";
    fzf = "A command-line fuzzy finder written in Go";
    git = "Distributed version control system";
    helix = "A post-modern modal text editor";

    # GUI applications
    firefox = "A web browser built from Firefox source tree";
    vscode = "Open source source code editor developed by Microsoft";
    mpv = "General-purpose media player, fork of MPlayer and mplayer2";

    # System tools
    direnv = "A shell extension that manages your environment";
    wl-gammarelay = "Screen color temperature manager";
    sops = "Simple and flexible tool for managing secrets";
  };

  # Standard package categories for consistent organization
  packageCategories = {
    essential = "Core system utilities";
    development = "Development tools and IDEs";
    multimedia = "Media playback and editing";
    productivity = "Office and productivity applications";
    gaming = "Games and gaming platforms";
    network = "Network tools and utilities";
    security = "Security and privacy tools";
  };
}
