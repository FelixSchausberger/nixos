{pkgs, ...}: {
  imports = [
    ../../shared
    ../../shared/gui/cosmic
    ../../shared/gui/gnome.nix
    ../../work
  ];

  home.packages = with pkgs; [
    openssl # Cryptographic library that implements the SSL and TLS protocols
  ];
}
