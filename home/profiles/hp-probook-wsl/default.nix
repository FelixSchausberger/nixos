{lib, ...}: {
  imports = [
    ../../../modules/home/tui-only.nix
    ../../../modules/home/profiles/features.nix
    ../../../modules/home/work/git.nix # Add work Git config
    ./glazewm.nix
    ../../persistence-tui.nix
  ];

  # Keep theming disabled for TUI-only environment
  theme.enable = lib.mkForce false;

  # Feature-based configuration for WSL work environment
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go" "rust" "javascript"];
    };

    # Enable work-specific tools
    work = {
      enable = true;
    };
  };

  # WSL-specific home configuration
  # Focus on terminal applications and CLI tools
  programs = {
    # Enable direnv for project-specific environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Enhanced shell experience
    starship.enable = true;
    zoxide.enable = true;

    # Git configuration (likely already in shared.nix)
    git.enable = true;
  };

  # WSL-specific home configuration
  home = {
    # Environment variables
    sessionVariables = {
      # Help with WSL display issues if X11 forwarding is used
      DISPLAY = ":0";
      # Optimize for WSL environment
      WSL_DISTRO_NAME = "nixos";
    };
  };
}
