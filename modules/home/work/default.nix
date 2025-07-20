{pkgs, ...}: {
  imports = [
    # Work-specific modules
    ./shells/fish.nix # Smart and user-friendly command line shell
    ./tui/awscli.nix
    ./tui/work-git-features.nix
  ];

  home.packages = with pkgs; [
    # Communication
    teams-for-linux # Unofficial Microsoft Teams client for Linux

    # Infrastructure and security
    nss_latest # Set of libraries for development of security-enabled client and server applications
    opentofu # Tool for building, changing, and versioning infrastructure
    openvpn # robust and highly flexible tunneling application
    sqlite # Self-contained, serverless, zero-configuration, transactional SQL database engine
    tlp # Advanced Power Management for Linux
    vault # Tool for managing secrets
  ];
}
