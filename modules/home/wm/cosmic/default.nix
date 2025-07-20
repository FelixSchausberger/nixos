{inputs, ...}: {
  imports = [
    inputs.cosmic-manager.homeModules.cosmic-manager
    ./cosmic-applets.nix
    ./cosmic-compositor.nix
    ./cosmic-files.nix
    ./cosmic-panels.nix
    ./cosmic-shortcuts.nix
    ./cosmic-term.nix
    ./cosmic-wallpapers.nix
    ./gammastep.nix # Screen color temperature manager
  ];

  programs.bash = {
    enable = true;

    # Auto-start cosmic when logging into TTY1
    bashrcExtra = ''
      # Check if on TTY1 and start cosmic-session if necessary
      if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
        pidof mylock > /dev/null || exec cosmic-session
      fi
    '';
  };

  programs = {
    cosmic-ext-ctl.enable = true; # CLI for COSMIC Desktop configuration management
    cosmic-manager.enable = true; # Manage COSMIC desktop declaratively using home-manager
    cosmic-ext-tweaks.enable = true; # A tweaking tool for the COSMIC desktop
  };

  wayland.desktopManager.cosmic = {
    enable = true;
    resetFiles = true;
  };
}
