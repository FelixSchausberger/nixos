{
  lib,
  pkgs,
  ...
}: {
  # WSL headless profile: TUI-only work environment.
  imports = [
    ../../../modules/home/tui-only.nix
    ../../../modules/home/work/git.nix # Add work Git config
  ];

  # Feature-based configuration for WSL development environment
  features = {
    development = {
      enable = true;
      languages = [
        "nix"
        "python"
        "go"
        "rust"
        "javascript"
      ];
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

  # Interactive homelab access always uses mosh: roaming-friendly, survives
  # suspend and network changes. mosh reads ~/.ssh/config for the bootstrap
  # connection, so keys and host aliases apply unchanged. Plain ssh stays
  # available for scripts and scp.
  programs.fish.functions.m920q = {
    body = ''
      command mosh m920q $argv
    '';
    description = "Interactive mosh session to m920q homelab";
  };

  # WSL-specific home configuration
  home = {
    packages = with pkgs; [
      lazyssh
      mosh
      # resize from xterm: reliable terminal size query via escape sequences
      # on WSL+systemd the pty initializes at 80x24; resize asks the terminal
      # emulator for actual dimensions and sets stty accordingly
      xterm
    ];

    sessionVariables = {
      EDITOR = "hx";
    };
  };
}
