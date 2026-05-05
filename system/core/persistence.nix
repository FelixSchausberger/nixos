{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  # System-level persistence configuration
  # This defines what system data survives reboots in an impermanent setup
  systemd.tmpfiles.rules = [
    "d /per/repos 0755 schausberger users -"
    "d /var/empty 0755 root root -"
  ];

  # Impermanence can leave cleanup paths transiently unavailable for tmpfiles jobs.
  # Treat CANTCREAT as non-fatal for setup/clean phases.
  systemd.services.systemd-tmpfiles-clean = {
    serviceConfig = {
      ExecStart = lib.mkForce [
        ""
        "${pkgs.systemd}/bin/systemd-tmpfiles --clean --exclude-prefix=/tmp --exclude-prefix=/var/tmp --exclude-prefix=/nix/var/nix --exclude-prefix=/var/lib/systemd"
      ];
      SuccessExitStatus = lib.mkAfter [
        "CANTCREAT"
      ];
    };
  };

  systemd.services.systemd-tmpfiles-setup = {
    serviceConfig = {
      ExecStart = lib.mkForce [
        ""
        "${pkgs.systemd}/bin/systemd-tmpfiles --create --remove --boot --exclude-prefix=/dev --exclude-prefix=/nix/var/nix --exclude-prefix=/var/lib/systemd --exclude-prefix=/tmp --exclude-prefix=/var/tmp"
      ];
      SuccessExitStatus = lib.mkAfter [
        "CANTCREAT"
      ];
    };
  };

  systemd.services.systemd-tmpfiles-resetup = {
    serviceConfig = {
      ExecStart = lib.mkForce [
        ""
        "${pkgs.systemd}/bin/systemd-tmpfiles --create --remove --exclude-prefix=/dev --exclude-prefix=/nix/var/nix --exclude-prefix=/var/lib/systemd --exclude-prefix=/tmp --exclude-prefix=/var/tmp"
      ];
      SuccessExitStatus = lib.mkAfter [
        "CANTCREAT"
      ];
    };
  };

  environment.persistence."/per" = {
    hideMounts = true;

    # System directories that must persist
    directories = [
      # Network configuration - WiFi passwords, VPN configs
      {
        directory = "/etc/NetworkManager/system-connections";
        user = "root";
        group = "root";
        mode = "0700";
      }

      # Bluetooth device pairings and settings
      {
        directory = "/var/lib/bluetooth";
        user = "root";
        group = "root";
        mode = "0755";
      }

      # System logs for debugging and monitoring
      {
        directory = "/var/log";
        user = "root";
        group = "root";
        mode = "0755";
      }

      # NixOS configuration state
      {
        directory = "/var/lib/nixos";
        user = "root";
        group = "root";
        mode = "0755";
      }

      # Core dumps for debugging
      {
        directory = "/var/lib/systemd/coredump";
        user = "root";
        group = "root";
        mode = "0755";
      }

      # Docker containers and images
      {
        directory = "/var/lib/docker";
        user = "root";
        group = "root";
        mode = "0711";
      }

      # Libvirt virtual machines
      {
        directory = "/var/lib/libvirt";
        user = "root";
        group = "root";
        mode = "0755";
      }
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

        # Git configuration (includes GitHub SSH rewrite rules)
        ".config/git"

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

        # Code repositories (GitHub clones, Rust projects, etc.)
        "repos"
      ];
    };
  };
}
