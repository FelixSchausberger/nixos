{
  lib,
  inputs,
  config,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  # Base home configuration - only TUI essentials
  # GUI hosts should explicitly import ./gui, ./themes, ./wallpapers
  imports = [
    ./shells
    ./tui
    ./themes # Contains both TUI and GUI themes with separation
  ];

  # Default to TUI-only theming (GUI hosts can enable theme.gui.enable)
  theme = {
    tui.enable = lib.mkDefault true; # Enable TUI themes by default
    gui.enable = lib.mkDefault false; # GUI themes disabled by default
  };

  # Required by home-manager's contacts module (no default upstream);
  # relative path is resolved against homeDirectory
  accounts.contact.basePath = lib.mkDefault ".local/share/contacts";

  # Basic home configuration
  home = {
    username = lib.mkDefault defaults.system.user;
    homeDirectory = lib.mkDefault defaults.paths.homeDir;

    # Keep the Go module/bin tree out of $HOME: the GOPATH default (~/go,
    # written by gopls and `go get`) moves to an XDG data directory. less
    # history/lesskey and nix-index's auto-run follow the same XDG-cleanliness
    # pattern (NIX_AUTO_RUN: nix-index's command-not-found handler runs
    # missing commands via nix-shell without installing them).
    sessionVariables = {
      GOPATH = "${config.xdg.dataHome}/go";
      LESSHISTFILE = "${config.xdg.dataHome}/less/history";
      LESSKEY = "${config.xdg.dataHome}/less/lesskey";
      DIRENV_LOG_FORMAT = "";
      NIX_AUTO_RUN = "1";
    };

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    stateVersion = defaults.system.version;
  };
}
