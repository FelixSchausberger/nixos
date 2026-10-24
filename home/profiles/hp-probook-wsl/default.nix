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

  # Interactive homelab access: mosh over the LAN, then over the tailnet, then
  # the Zellij web attach. The LAN alias carries a 3s ConnectTimeout
  # (modules/home/tui/git.nix) because its RFC1918 address is unroutable off
  # the home network, so the tailnet attempt costs one bounded stall and
  # reaches m920q from anywhere. mosh is roaming-friendly (survives suspend and
  # network changes) and reads ~/.ssh/config for the bootstrap connection, so
  # keys and host aliases apply unchanged. Its stmclient "Timed out waiting for
  # server..." path is what a UDP-filtered network produces; `zr` then takes
  # over over HTTPS and carries its own reconnect loop. Plain ssh stays
  # available for scripts, scp and a raw shell when Zellij itself is broken.
  programs.fish.functions.m920q = {
    body = ''
      command mosh m920q $argv
      or command mosh m920q-tail $argv
      or begin
        echo "m920q: mosh could not reach the homelab over the LAN or the tailnet, attaching through the Zellij web transport" >&2
        zr
      end
    '';
    description = "Homelab session: mosh over LAN or tailnet, falling back to the Zellij web attach";
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
