{pkgs, ...}: {
  imports = [
    # Work configuration
    ../../../modules/home/work
    # TUI tools including rclone
    ../../../modules/home/tui
  ];

  # Host-specific packages and configuration
  home.packages = with pkgs; [
    # Security and networking
    openssl # Cryptographic library that implements the SSL and TLS protocols
  ];
}
