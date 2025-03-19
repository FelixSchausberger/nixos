{
  config,
  inputs,
  pkgs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in {
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
    (inputs.impermanence + "/home-manager.nix")
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

    theme = spicePkgs.themes.hazy;
  };

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      ".cache/spotify"
      ".config/spotify"
    ];
  };
}
