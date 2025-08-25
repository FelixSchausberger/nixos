# Home modules for TUI-only hosts (WSL, headless, etc.)
{lib, ...}: {
  imports = [
    ./shells
    ./terminals
    ./tui
  ];

  # Disable centralized theming for TUI-only hosts
  theme.enable = lib.mkDefault false;

  # Basic home configuration
  home = {
    username = lib.mkDefault "schausberger";
    homeDirectory = lib.mkDefault "/home/schausberger";

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    stateVersion = "25.11";
  };
}
