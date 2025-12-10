{
  pkgs,
  lib,
  hostConfig,
  ...
}: {
  config = lib.mkIf (builtins.elem "gnome" hostConfig.wm) {
    services = {
      desktopManager.gnome.enable = true;
      gnome.gnome-keyring.enable = true;

      # Better hardware compatibility
      libinput = {
        enable = true;
        touchpad = {
          naturalScrolling = true;
          tapping = true;
        };
      };

      # Needed to get systray icons
      udev.packages = [pkgs.gnome-settings-daemon];
    };

    # GNOME-specific PAM configuration for greetd
    # Note: login.enableGnomeKeyring is set in shared-security.nix
    security.pam.services = {
      greetd.enableGnomeKeyring = true;
    };

    environment = {
      # Fix cursor theme for GNOME to match Hyprland
      sessionVariables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
      };

      systemPackages = with pkgs;
        [
          # Cursor theme package
          bibata-cursors
        ]
        ++ (with pkgs.gnomeExtensions; [
          caffeine # Status bar application to temporarily inhibit screensaver and sleep mode
          appindicator # Adds AppIndicator, KStatusNotifierItem and legacy Tray icons support to the Shell
          blur-my-shell # Adds a blur look to different parts of the GNOME Shell
          clipboard-history # Clipboard manager
          # gsconnect # KDE Connect implementation for Gnome Shell
          pop-shell #  Keyboard-driven layer for GNOME Shell
          vitals # A glimpse into your computer's stats
          compiz-windows-effect # Adds wobbly windows and other effects
          transparent-window-moving # Makes windows transparent while moving
        ]);

      gnome.excludePackages = with pkgs; [
        atomix # puzzle game
        cheese # webcam tool
        epiphany # web browser
        evince # document viewer
        geary # email reader
        gedit # text editor
        gnome-characters
        gnome-music
        gnome-photos
        gnome-terminal
        gnome-tour
        hitori # sudoku game
        iagno # go game
        tali # poker game
        totem # video player
      ];
    };
  };
}
