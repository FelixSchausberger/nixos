# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    "${inputs.impermanence}/nixos.nix"
    ./security
    ./users.nix
  ];

  documentation.dev.enable = true;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    # Saves space
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "de_AT.UTF-8/UTF-8"
    ];
  };

  # Set your time zone.
  time.timeZone = lib.mkDefault "Europe/Vienna";

  programs.fuse.userAllowOther = true;

  # Configure system-wide files.
  environment = {
    etc = {
      nixos.source = "${inputs.self}";

      "ssh/ssh_host_ed25519_key.pub" = {
        source = config.sops.secrets."ssh/authorized_keys/regular".path;
      };
    };

    systemPackages = with pkgs; [
      xdg-utils # Set of command line tools that assist applications with a variety of desktop integration tasks
      age # Modern encryption tool with small explicit keys
      ssh-to-age # Convert ssh private keys in ed25519 format to age keys
      sops # Simple and flexible tool for managing secrets
    ];

    persistence."/per" = {
      hideMounts = true;
      directories = [
        "/var/log" # Stores system and application logs essential for troubleshooting and auditing
        "/var/lib/nixos" # Contains state files for NixOS, critical for preserving system and package state across reboots
        "/var/lib/systemd/coredump" # Stores core dumps from crashed applications, useful for debugging and analyzing issues
      ];
      files = [
        "/etc/machine-id" # A unique identifier for the system, used by systemd and other services for consistent identification
      ];
      users.${inputs.self.lib.user} = {
        directories = [
          "Downloads"
          "Music"
          "Pictures"
          "Documents"
          "Videos"
          {
            directory = ".local/share/fish";
            mode = "0700";
          }
        ];
      };
    };
  };

  sops.secrets = {
    "ssh/authorized_keys/regular" = {};
  };

  services = {
    # Simple interprocess messaging system
    dbus.enable = true;

    # Support for mounting other filesystems
    gvfs.enable = true;
  };

  # Compresses half the ram for use as swap
  # zramSwap.enable = true;

  system.stateVersion = lib.mkDefault "25.05";
}
