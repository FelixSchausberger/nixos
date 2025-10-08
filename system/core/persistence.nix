{inputs, ...}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  # System-level persistence configuration
  # This defines what system data survives reboots in an impermanent setup
  environment.persistence."/per" = {
    hideMounts = true;

    # System directories that must persist
    directories = [
      # Network configuration - WiFi passwords, VPN configs
      "/etc/NetworkManager/system-connections"

      # Bluetooth device pairings and settings
      "/var/lib/bluetooth"

      # System logs for debugging and monitoring
      "/var/log"

      # NixOS configuration state
      "/var/lib/nixos"

      # Core dumps for debugging
      "/var/lib/systemd/coredump"

      # Docker containers and images
      "/var/lib/docker"

      # Libvirt virtual machines
      "/var/lib/libvirt"
    ];

    # User-specific persistent data
    users.${inputs.self.lib.user} = {
      directories = [
        # SSH keys and known hosts
        {
          directory = ".ssh";
          mode = "0700";
        }

        # GPG keys and trust database
        {
          directory = ".gnupg";
          mode = "0700";
        }

        # Shell history and fish data
        ".local/share/fish"

        # System keyring
        ".local/share/keyrings"

        # User directories
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
      ];
    };
  };
}
