{pkgs, ...}: {
  imports = [
    ./fish.nix # Smart and user-friendly command line shell
    # ./awscli.nix # Commented out as AWS CLI no longer needed
    ./git.nix
  ];

  home.packages = with pkgs; [
    teams-for-linux # Unofficial Microsoft Teams client for Linux
    nss_latest # Set of libraries for development of security-enabled client and server applications
    openssl # Cryptographic library that implements the SSL and TLS protocols
    opentofu # Tool for building, changing, and versioning infrastructure
    openvpn # robust and highly flexible tunneling application
    sqlite # Self-contained, serverless, zero-configuration, transactional SQL database engine
    tlp # Advanced Power Management for Linux
    vault # Tool for managing secrets
  ];
}
