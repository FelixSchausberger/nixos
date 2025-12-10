{
  lib,
  pkgs,
  ...
}: {
  # VMware VM profile with Niri window manager
  imports = [
    ../../../modules/home/work/git.nix # Add work Git config
  ];

  # Enable Niri window manager
  wm.niri = {
    enable = true;
    browser = "firefox";
    terminal = "ghostty";
    fileManager = "cosmic-files";
  };

  # Feature-based configuration for development environment
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go" "rust" "javascript"];
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

    # Environment variables for Wayland
    sessionVariables = {
      GDK_BACKEND = lib.mkDefault "wayland,x11";
      QT_QPA_PLATFORM = lib.mkDefault "wayland;xcb";
    };
  };
}
