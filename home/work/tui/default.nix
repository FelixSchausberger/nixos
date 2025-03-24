{pkgs, ...}: {
  imports = [
    ./awscli.nix # Unified tool to manage your AWS services
    ./git.nix # Distributed version control system
    ./sops.nix # Simple and flexible tool for managing secrets
  ];

  home.packages = with pkgs; [
    # openvpn # robust and highly flexible tunneling application
    teams-for-linux # Unofficial Microsoft Teams client for Linux
    tlp # Advanced Power Management for Linux
  ];
}
