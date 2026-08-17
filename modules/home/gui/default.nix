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

  # Simple single-package applications
  home.packages = with pkgs; [
    oculante # Minimalistic image viewer
  ];

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
