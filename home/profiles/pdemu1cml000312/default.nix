{pkgs, ...}: {
  imports = [
    ../../../modules/home
    ../../../modules/home/gui/cosmic
    ../../../modules/home/gui/gnome.nix
    ../../../modules/home/work
  ];

  home.packages = with pkgs; [
    openssl # Cryptographic library that implements the SSL and TLS protocols
  ];
}
