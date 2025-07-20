{pkgs, ...}: {
  # Import configurations of graphical applications
  imports = [
    ./browsers # Web browsers (Chrome, Firefox, Zen)
    ./editors # Editors (VS Code, Zed)
    ./mpv.nix # General-purpose media player, fork of MPlayer and mplayer2
    ./obsidian.nix # A powerful knowledge base
    ./planify.nix # Task manager with Todoist support designed for GNU/Linux
    ./spicetify.nix # Play music from the Spotify music service
  ];

  home.packages = with pkgs; [
    # celeste # GUI file synchronization client that can sync with any cloud provider
    fractal # Matrix group messaging app
    gimp # The GNU Image Manipulation Program
  ];
}
