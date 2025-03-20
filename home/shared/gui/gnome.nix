{pkgs, ...}: {
  home.packages = with pkgs; [
    # caffeine-ng # Status bar application to temporarily inhibit screensaver and sleep mode
    # gnome-extension-manager # Desktop app for managing GNOME shell extensions
    gnome-tweaks # Tool to customize advanced GNOME 3 options
    # flameshot # Powerful yet simple to use screenshot software
    satty # Screenshot annotation tool inspired by Swappy and Flameshot
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
