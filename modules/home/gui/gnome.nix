{pkgs, ...}: {
  home.packages = with pkgs; [
    gnome-tweaks # Tool to customize advanced GNOME 3 options
    # satty # Screenshot annotation tool inspired by Swappy and Flameshot
    wl-clipboard # Command-line copy/paste utilities for Wayland
  ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
      "org/gnome/shell" = {
        disable-user-extensions = false; # Enables user extensions
        enabled-extensions = with pkgs.gnomeExtensions; [
          caffeine.extensionUuid
          appindicator.extensionUuid
          blur-my-shell.extensionUuid
          clipboard-history.extensionUuid
          # gsconnect.extensionUuid
          pop-shell.extensionUuid
          vitals.extensionUuid
        ];
      };
    };
  };
}
