{
  lib,
  pkgs,
  ...
}: {
  # WSL-specific profile - no GUI imports from shared.nix
  # This profile is designed for TUI-only workflow with selective GUI apps
  imports = [
    ../../../modules/home/tui-only.nix
    ../../../modules/home/profiles/features.nix
    ../../../modules/home/work/git.nix # Add work Git config
  ];

  # Keep GUI theming disabled for TUI-only WSL environment
  theme.gui.enable = lib.mkForce false;

  # Feature-based configuration for WSL development environment
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go" "rust" "javascript"];
    };
  };

  # Fix missing calendar configuration that's causing evaluation errors
  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";

  # WSL-specific home configuration
  # Focus on terminal applications and CLI tools
  programs = {
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

      # WSL2/WSLg graphics optimization
      GDK_BACKEND = "x11"; # Force GTK to use X11
      QT_QPA_PLATFORM = "xcb"; # Force Qt to use X11

      # SSL/TLS certificate environment variables for user session (use enhanced bundle)
      SSL_CERT_FILE = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
      SSL_CERT_DIR = lib.mkForce "/etc/ssl/certs";
      CURL_CA_BUNDLE = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
      NIX_SSL_CERT_FILE = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
      # Additional certificate environment variables for various tools
      GIT_SSL_CAINFO = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
      NODE_EXTRA_CA_CERTS = lib.mkForce "/etc/ssl/certs/ca-bundle-enhanced.crt";
    };
  };
}
