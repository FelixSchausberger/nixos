{
  imports = [
    ../shared.nix
    ./hyprland.nix
    ../../../modules/home/profiles/features.nix
  ];

  # Feature-based configuration for WSL work environment
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go" "rust" "javascript"];
    };

    # Enable terminal-focused workflow since WSL doesn't have GUI by default
    terminal = {
      enable = true;
      enhanced = true;
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

  # WSL-specific environment variables
  home.sessionVariables = {
    # Help with WSL display issues if X11 forwarding is used
    DISPLAY = ":0";
    # Optimize for WSL environment
    WSL_DISTRO_NAME = "nixos";
  };
}
