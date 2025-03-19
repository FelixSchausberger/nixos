{pkgs, ...}: {
  # Import configurations of graphical applications
  imports = [
    # ./cosmic
    ./chromium.nix # Open source web browser from Google
    ./firefox # A web browser built from Firefox source tree
    ./mpv.nix # General-purpose media player, fork of MPlayer and mplayer2
    ./spicetify.nix # Play music from the Spotify music service
    ./vscode.nix # Open source source code editor developed by Microsoft
    ./zen.nix
  ];

  home.packages = with pkgs; [
    # celeste # GUI file synchronization client that can sync with any cloud provider
    fractal # Matrix group messaging app
    gimp # The GNU Image Manipulation Program
    # spacedrive # An open source file manager
    # zed-editor # High-performance, multiplayer code editor
  ];
}
