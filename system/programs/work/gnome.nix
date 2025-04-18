{pkgs, ...}: {
  services = {
    # displayManager = {
    #   autoLogin = {
    #     enable = true;
    #     user = "fesch";
    #   };
    #   defaultSession = "gnome";
    # };

    gnome.gnome-keyring.enable = true;

    xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
      displayManager.gdm.enable = true;
    };

    # Better hardware compatibility
    libinput = {
      enable = true;
      touchpad.naturalScrolling = true;
      touchpad.tapping = true;
    };

    # Needed to get systray icons
    udev.packages = [pkgs.gnome-settings-daemon];
  };

  # Workaround for auto login
  # https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  # systemd.services = {
  #   "getty@tty1".enable = false;
  #   "autovt@tty1".enable = false;
  # };

  security.pam.services.gdm.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs.gnomeExtensions; [
    caffeine # Status bar application to temporarily inhibit screensaver and sleep mode
    appindicator # Adds AppIndicator, KStatusNotifierItem and legacy Tray icons support to the Shell
    blur-my-shell # Adds a blur look to different parts of the GNOME Shell
    clipboard-history # Clipboard manager
    # gsconnect # KDE Connect implementation for Gnome Shell
    pop-shell #  Keyboard-driven layer for GNOME Shell
    vitals # A glimpse into your computer's stats
  ];

  environment.gnome.excludePackages = with pkgs; [
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
}
