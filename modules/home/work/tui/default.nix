{pkgs, ...}: {
  imports = [
    # ./awscli.nix # Unified tool to manage your AWS services - TEMPORARILY DISABLED DUE TO SOPS ISSUE
    ./work-git-features.nix
  ];

  home.packages = with pkgs; [
    nss_latest # Set of libraries for development of security-enabled client and server applications
    openvpn # robust and highly flexible tunneling application
    sqlite # Self-contained, serverless, zero-configuration, transactional SQL database engine
    tlp # Advanced Power Management for Linux
    vault # Tool for managing secrets
  ];
}
