{
  lib,
  inputs,
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

  # Basic home configuration
  home = {
    username = lib.mkDefault defaults.system.user;
    homeDirectory = lib.mkDefault defaults.paths.homeDir;

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    stateVersion = defaults.system.version;
  };
}
