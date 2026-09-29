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

  # OpenCode 2 beta spike (opencode2), isolated from the V1 config. Opt-in;
  # see modules/home/tui/ai-assistants/opencode/v2.nix.
  ai-assistants.opencodeV2.enable = true;

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

    # Link handler: the GUI module that declares the text/html default is not
    # imported here, so xdg-open has no handler to fall back to. Windows interop
    # is available on this host, and Explorer routes a URL argument to the
    # Windows default browser. newsboat appends the URL when the value carries
    # no %u placeholder.
    newsboat.browser = "/mnt/c/Windows/explorer.exe";

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
      # Link handlers for TUI tools: `gh browse` and other BROWSER consumers
      # would fall back to xdg-open, which has no handler on this host (see
      # the newsboat.browser override above for the same reason), and
      # circumflex reads CLX_BROWSER before xdg-open for its o/c keys.
      # Explorer routes a URL argument to the Windows default browser.
      BROWSER = "/mnt/c/Windows/explorer.exe";
      CLX_BROWSER = "/mnt/c/Windows/explorer.exe";
    };
  };
}
