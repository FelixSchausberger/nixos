{pkgs, ...}: {
  imports = [
    ./awscli.nix # Unified tool to manage your AWS services
    ./work-git-features.nix # Work Git feature additions
  ];

  home.packages = with pkgs; [
    nss_latest # Set of libraries for development of security-enabled client and server applications
    openvpn # robust and highly flexible tunneling application
    teams-for-linux # Unofficial Microsoft Teams client for Linux
    tlp # Advanced Power Management for Linux
    vault # Tool for managing secrets
  ];
}
