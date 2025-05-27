# home/hosts/pdemu1cml000312/tui/default.nix
{ pkgs, ... }: { # Retain pkgs argument if original file had it
  imports = [
    ./awscli.nix
    ../../../../modules/home/tui/git.nix # Base shared Git module
    ./git-features.nix                   # Work/host-specific Git additions
  ];

  # Keep other packages if they were in the original default.nix
  home.packages = with pkgs; [
    nss_latest
    openvpn
    teams-for-linux
    tlp
    vault
  ];
}
