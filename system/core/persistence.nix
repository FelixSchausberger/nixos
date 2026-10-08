{
  inputs,
  lib,
  pkgs,
  hostConfig,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  # System-level persistence configuration
  # This defines what system data survives reboots in an impermanent setup
  # /var/empty is provisioned by nixpkgs' activation module as 0555 with the
  # immutable bit set (sshd privilege-separation dir). Adding a chmod rule for
  # it here fails with EPERM on every boot after the immutable bit is applied.
  systemd.tmpfiles.rules = [
    "d /per/repos 0755 schausberger users -"
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

  # A stable machine-id. Under an ephemeral root systemd regenerates
  # /etc/machine-id every boot, so journald writes each boot into a fresh
  # /var/log/journal/<machine-id>/ directory and `journalctl` reads only the
  # current one: `journalctl -b -1` finds nothing and an incident's logs look
  # lost after a reboot even though /var/log persists. Other sd-id128 consumers
  # (DHCP DUID, application state) churn the same way.
  #
  # Declared as an /etc entry, not an impermanence `files` bind mount: the bind
  # mount is known to break systemd-machine-id-commit.service, which refuses a
  # transient id that is "not on a temporary file system"
  # (nix-community/impermanence#229). Activation restores this symlinked entry
  # from the store on every boot - in the initrd here, before stage-2 systemd -
  # so PID1 finds it and never generates a transient id.
  #
  # Derived from the hostname: stable and unique per host, disclosing nothing
  # beyond the (already public) hostname.
  environment.etc."machine-id" = {
    mode = "0444";
    text = builtins.substring 0 32 (builtins.hashString "sha256" "machine-id:${hostConfig.hostName}");
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
      directories =
        [
          # SSH keys and known hosts
          {
            directory = ".ssh";
            mode = "0700";
          }

          # SOPS age key for secret decryption
          {
            directory = ".config/sops";
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

          # User directories: Downloads and Pictures stay local on every host.
          # m920q serves the other three (Documents, Music, Videos) from the data
          # pool through symlinks in home/profiles/m920q/default.nix, so those
          # names are bound only there; on every other host they persist below.
          "Downloads"
          "Pictures"
        ]
        ++ lib.optionals (hostConfig.hostName != "m920q") [
          "Documents"
          "Music"
          "Videos"
        ];
    };
  };
}
