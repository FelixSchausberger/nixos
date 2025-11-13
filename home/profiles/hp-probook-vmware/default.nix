{
  lib,
  pkgs,
  ...
}: {
  # VMware VM profile with niri window manager support
  imports = [
    ../../../modules/home/tui-only.nix
    ../../../modules/home/work/git.nix # Add work Git config
  ];

  # Enable GUI theming for niri
  theme.gui.enable = lib.mkForce true;

  # Feature-based configuration for development environment
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go" "rust" "javascript"];
    };
  };

  # Niri configuration for VMware VM
  wm.niri = {
    enable = true;
    terminal = "ghostty";
    browser = "zen";
    fileManager = "cosmic-files";

    # Scratchpad applications
    scratchpad = {
      musicApp = "spotify";
      notesApp = "obsidian";
    };
  };

  # Fix missing calendar configuration
  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";

  # Home configuration for VMware VM
  programs = {
    # Enable good morning message at 7am
    claude-code.goodMorning = {
      enable = true;
      time = "07:00:00";
      message = "Good morning! Ready to start the day.";
    };

    # Enable direnv for project-specific environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Enhanced shell experience
    fish.enable = true;
    starship.enable = true;
    zoxide.enable = true;

    # Git configuration
    git.enable = true;
  };

  # VM-specific home configuration
  home = {
    # Useful packages for VM environment
    packages = with pkgs; [
      lazyssh # Terminal-based SSH manager
    ];

    # Environment variables for native Wayland
    sessionVariables = {
      # Wayland backend preferences
      GDK_BACKEND = lib.mkDefault "wayland,x11";
      QT_QPA_PLATFORM = lib.mkDefault "wayland;xcb";

      # Native niri will use DRM/KMS backend automatically
      # No need for NIRI_BACKEND=winit (that's WSL-specific)
    };
  };
}
