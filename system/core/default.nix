# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
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
    etc.nixos.source = "${inputs.self}";

    systemPackages = with pkgs; [
      fuse # Library that allows filesystems to be implemented in user space
      fuse3 # Library that allows filesystems to be implemented in user space
      bindfs # FUSE filesystem for mounting a directory to another location
      xdg-utils # Set of command line tools that assist applications with a variety of desktop integration tasks
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
