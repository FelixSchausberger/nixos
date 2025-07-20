{pkgs, ...}: {
  # Import configurations of graphical applications
  imports = [
    ./browsers # Web browsers (Chrome, Firefox, Zen)
    ./editors # Editors (VS Code, Zed)
    # ./calibre.nix # Comprehensive e-book software
    ./mpv.nix # General-purpose media player, fork of MPlayer and mplayer2
    ./obsidian.nix # A powerful knowledge base
    ./oculante.nix # A minimalistic crossplatform image viewer written in Rust
    ./planify.nix # Task manager with Todoist support designed for GNU/Linux
    ./prusaslicer.nix # G-code generator for 3D printer
    ./sioyek.nix # A PDF viewer
    ./spicetify.nix # Play music from the Spotify music service
  ];

  home.packages = with pkgs; [
    # celeste # GUI file synchronization client that can sync with any cloud provider
    fractal # Matrix group messaging app
    gimp # The GNU Image Manipulation Program
    # rnote # Simple drawing application to create handwritten notes
    # qbittorrent-enhanced # Unofficial enhanced version of qBittorrent, a BitTorrent client
  ];
}
