{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  enabled = config.features.media.enable;
in {
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  systemd.user.services.spotify = lib.mkIf enabled {
    serviceConfig.Environment = let
      libs = with pkgs; [
        libx11
        libxscrnsaver
        libxtst
        libxkbcommon
        libdbusmenu-gtk3
        libayatana-indicator
      ];
    in ["LD_PRELOAD=${pkgs.lib.makeLibraryPath libs}"];
  };

  home.packages = lib.mkIf enabled (with pkgs; [
    libayatana-indicator
    libdbusmenu
  ]);

  programs.spicetify = lib.mkIf enabled {
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

    # Theme and colorScheme are controlled by stylix for system-wide consistency
  };
}
