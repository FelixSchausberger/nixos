# https://yazi-rs.github.io/docs/resources/
# https://github.com/AnirudhG07/awesome-yazi
{
  imports = [
    ./chmod.nix # Execute chmod on the selected files to change their mode.
    ./clipboard.nix # Yazi plugin for copy file to clipboard,support linux and windows.
    ./eza-preview.nix # Preview directories using eza.
    ./fg.nix # A Yazi plugin that supports file searching with a fuzzy preview.
    ./git.nix # Show the status of Git file changes as linemode in the file list.
    ./mount.nix # User interface for convinient mounting volumes using udisks2.
    # ./starship.nix # Starship prompt plugin for Yazi.
  ];
}
