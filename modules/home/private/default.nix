{pkgs, ...}: {
  imports = [
    # GUI applications
    ./gui/oculante.nix # A minimalistic crossplatform image viewer written in Rust
    ./gui/sioyek.nix # A PDF viewer

    # TUI tools
    ./tui/git.nix # Distributed version control system
    ./tui/typix.nix # Typst: A markup-based typesetting system
  ];

  home.packages = with pkgs; [
    # Creative applications
    blender # 3D Creation/Animation/Publishing System
    krita # A free and open source painting application
    rnote # Simple drawing application to create handwritten notes

    # System utilities
    libwacom # Libraries, configuration, and diagnostic tools for Wacom tablets running under Linux
    qbittorrent # Featureful free software BitTorrent client
    vial # Open-source GUI and QMK fork for configuring your keyboard in real time
  ];
}
