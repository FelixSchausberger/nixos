# Home modules for TUI-only hosts (WSL, headless, etc.)
{
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  imports = [
    ./shells
    ./tui
  ];

  # Enable only TUI theming for TUI-only hosts
  theme = {
    tui.enable = lib.mkDefault true; # Enable TUI themes
    gui.enable = lib.mkDefault false; # Disable GUI themes
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
