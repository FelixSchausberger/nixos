{lib, ...}: {
  imports = [
    ./gui
    ./shells
    ./terminals
    ./themes
    ./tui
    ./wallpapers
  ];

  # Enable centralized theming system
  theme.enable = lib.mkDefault true;
  
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
