{
  inputs,
  pkgs,
  ...
}: {
  services = {
    displayManager = {
      autoLogin = {
        enable = true;
        user = "${inputs.self.lib.user}";
        # inherit (conf) user;
      };
      defaultSession = "gnome";
    };

    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };
  };

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

  home-manager.users."${inputs.self.lib.user}" = {
    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/interface".color-scheme = "prefer-dark";
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = with pkgs.gnomeExtensions; [
            blur-my-shell.extensionUuid
            # gsconnect.extensionUuid
          ];
        };
      };
    };
  };
}
