{pkgs, ...}: {
  # Import configurations of graphical applications
  imports = [
    ./calibre.nix # Comprehensive e-book software
    ./obsidian.nix # A powerful knowledge base
    ./oculante.nix # # A minimalistic crossplatform image viewer written in Rust
    ./planify.nix # Task manager with Todoist support
    ./sioyek.nix # A PDF viewer
  ];

  home.packages = with pkgs; [
    blender # 3D Creation/Animation/Publishing System
    krita # A free and open source painting application
    libwacom # Libraries, configuration, and diagnostic tools for Wacom tablets running under Linux
    qbittorrent # Featureful free software BitTorrent client
    rnote # Simple drawing application to create handwritten notes
    # upscayl # Free and Open Source AI Image Upscaler
    vial # # Open-source GUI and QMK fork for configuring your keyboard in real time
  ];
}
