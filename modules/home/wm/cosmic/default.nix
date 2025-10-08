{inputs, ...}: {
  imports = [
    inputs.cosmic-manager.homeManagerModules.cosmic-manager
    ./cosmic-applets.nix
    ./cosmic-compositor.nix
    ./cosmic-files.nix
    ./cosmic-panels.nix
    ./cosmic-shortcuts.nix
    ./cosmic-term.nix
    ./cosmic-wallpapers.nix
    # Use shared compositor-agnostic modules with cosmic session target
    (import ../shared/wl-gammarelay.nix "cosmic-session.target") # Screen color temperature manager
    # (import ../shared/cthulock.nix "cosmic-session.target") # Screen locker - disabled until package is fixed
    (import ../shared/wpaperd.nix "cosmic-session.target") # Wallpaper daemon
    ../shared/satty.nix # Screenshot tool
    ../shared/vigiland-simple.nix # Wayland idle inhibitor
    # (import ../shared/ala-lape.nix "cosmic-session.target") # Idle inhibitor - disabled until package is fixed
    # (import ../shared/wlsleephandler-rs.nix "cosmic-session.target") # Sleep handler - disabled until package is fixed
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
