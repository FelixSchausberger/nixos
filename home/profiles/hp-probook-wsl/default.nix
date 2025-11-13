{
  lib,
  pkgs,
  ...
}: {
  # WSL-specific profile with niri window manager support
  imports = [
    ../../../modules/home/tui-only.nix
    ../../../modules/home/work/git.nix # Add work Git config
  ];

  # Enable GUI theming for niri
  theme.gui.enable = lib.mkForce true;

  # Feature-based configuration for WSL development environment
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go" "rust" "javascript"];
    };
  };

  # Niri configuration for WSL
  wm.niri = {
    enable = true; # Enable niri for WSL
    terminal = "ghostty";
    browser = "zen";
    fileManager = "cosmic-files";

    # WSL-specific: minimal scratchpad apps
    scratchpad = {
      musicApp = "spotify";
      notesApp = "obsidian";
    };
  };

  # Disable xwayland-satellite for Wayland-only setup (remove from auto-start)
  # systemd.user.services.xwayland-satellite.Install.WantedBy = lib.mkForce [];

  # Fix missing calendar configuration that's causing evaluation errors
  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";

  # WSL-specific home configuration
  # Focus on terminal applications and CLI tools
  programs = {
    # Enable claude-wsl integration for visual notifications
    claude-code.wsl.enable = true;

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

    # Git configuration (likely already in shared.nix)
    git.enable = true;
  };

  # WSL-specific home configuration
  home = {
    # WSL backup aliases (shell-agnostic)
    shellAliases = {
      wsl-backup = "sudo /per/etc/nixos/tools/scripts/wsl-backup-hpprobook.sh backup";
      wsl-restore = "sudo /per/etc/nixos/tools/scripts/wsl-backup-hpprobook.sh restore";
      wsl-backup-verify = "sudo /per/etc/nixos/tools/scripts/wsl-backup-hpprobook.sh verify";
    };

    # WSL work-specific packages
    packages = with pkgs; [
      lazyssh # Terminal-based SSH manager
    ];

    # Environment variables
    sessionVariables = {
      # Help with WSL display issues if X11 forwarding is used
      DISPLAY = ":0";
      # Optimize for WSL environment
      WSL_DISTRO_NAME = "nixos";

      # WSL2/WSLg graphics optimization - use Wayland when niri is running
      # These will be overridden by niri's Wayland session variables
      GDK_BACKEND = lib.mkDefault "wayland,x11";
      QT_QPA_PLATFORM = lib.mkDefault "wayland;xcb";

      # Force niri to run nested inside the WSLg Wayland session
      # NIRI_BACKEND = lib.mkDefault "winit";
      # WINIT_UNIX_BACKEND = lib.mkDefault "wayland";
    };
  };
}
