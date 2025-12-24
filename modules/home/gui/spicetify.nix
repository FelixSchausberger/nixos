{
  inputs,
  pkgs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  systemd.user.services.spotify = {
    serviceConfig.Environment = let
      libs = with pkgs; [
        xorg.libX11
        xorg.libXScrnSaver
        xorg.libXtst
        libxkbcommon
        libdbusmenu-gtk3
        libayatana-indicator
      ];
    in ["LD_PRELOAD=${pkgs.lib.makeLibraryPath libs}"];
  };

  home.packages = with pkgs; [
    libayatana-indicator
    libdbusmenu
  ];

  programs.spicetify = {
    enable = true;

    # https://github.com/the-argus/spicetify-nix/blob/master/EXTENSIONS.md
    enabledExtensions = with spicePkgs.extensions; [
      adblock # Remove ads.
      fullAlbumDate # Display the day and month of an album's release, as well as the year.
      history # Adds a page that shows your listening history.
      keyboardShortcut # Vimium-like navigation of spotify. Keyboard shortcuts: https://spicetify.app/docs/advanced-usage/extensions#keyboard-shortcut
      shuffle # Shuffle properly, using Fisher-Yates with zero bias.
      playlistIcons # Give your playlists icons in the left sidebar.
    ];

    # experimentalFeatures = true;

    # theme = spicePkgs.themes.hazy;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "macchiato";
  };
}
