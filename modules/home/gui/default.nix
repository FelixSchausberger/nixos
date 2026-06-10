{pkgs, ...}: {
  # Import configurations of graphical applications
  imports = [
    ./browsers # Web browsers (Chrome, Firefox, Zen)
    ./editors # Editors (VS Code, Zed)
    ./terminals # Terminal emulators (Ghostty)
    # ./calibre.nix # Comprehensive e-book software
    ./mpv.nix # General-purpose media player, fork of MPlayer and mplayer2
    ./obsidian.nix # A powerful knowledge base
    ./prusaslicer.nix # G-code generator for 3D printer (kept separate due to activation scripts)
    ./sioyek.nix # A PDF viewer
    ./spicetify.nix # Play music from the Spotify music service
  ];

  # Simple single-package applications (consolidated from individual files)
  home.packages = with pkgs; [
    # Previously individual modules, now consolidated:
    freecad # 3D CAD software (was freecad.nix)
    oculante # Minimalistic image viewer (was oculante.nix)
    planify # Task manager with Todoist support (was planify.nix)
    steam # Gaming platform (was steam.nix)

    # Font needed for planify (from planify.nix)
    noto-fonts-emoji-blob-bin

    # Other applications:
    # celeste # GUI file synchronization client that can sync with any cloud provider
    fractal # Matrix group messaging app
    gimp # The GNU Image Manipulation Program
    # rnote # Simple drawing application to create handwritten notes
    # qbittorrent-enhanced # Unofficial enhanced version of qBittorrent, a BitTorrent client
  ];

  # Font configuration needed for planify (from planify.nix)
  fonts.fontconfig.enable = true;

  # MIME type associations for oculante (from oculante.nix)
  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "image/gif" = ["oculante.desktop"];
        "image/jpg" = ["oculante.desktop"];
        "image/jpeg" = ["oculante.desktop"];
        "image/png" = ["oculante.desktop"];
      };
    };

    desktopEntries.oculante = {
      name = "Oculante";
      exec = "${pkgs.oculante}/bin/oculante";
    };
  };
}
