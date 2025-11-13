{
  lib,
  inputs,
  modulesPath,
  ...
}: let
  hostName = "installer";
  repoPath = inputs.self;
  authorizedKeysFile = ./authorized_keys;
  hasAuthorizedKeys = builtins.pathExists authorizedKeysFile;
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../default/00-host-config.nix
    ../default/10-sops.nix
    ../../system/core
    ../../system/hardware
    ../../system/network.nix
    ../shared-tui.nix
    ../../modules/system/recovery-tools.nix
  ];

  hostConfig = {
    inherit hostName;
    isGui = false;
    wm = [];
  };

  boot = {
    supportedFilesystems = [
      "zfs"
      "ext4"
      "btrfs"
      "xfs"
      "ntfs"
    ];
    kernelModules = [
      "zfs"
    ];
  };

  networking.hostName = hostName;

  users.users.root.openssh.authorizedKeys.keyFiles =
    lib.optionals hasAuthorizedKeys [authorizedKeysFile];

  systemd.tmpfiles.rules = [
    "d /per 0755 root root -"
    "d /per/etc 0755 root root -"
  ];

  system.activationScripts.installRepo = ''
    mkdir -p /per/etc
    ln -sfn ${repoPath} /per/etc/nixos
  '';

  # Ensure the portable scripts know where the configuration lives
  environment.sessionVariables.NIXOS_CONFIG_ROOT = "/per/etc/nixos";

  # Fix sudo conflict between installation-device.nix and sudo-rs.nix
  # Keep security.sudo (from installation-device) and disable sudo-rs
  security.sudo-rs.enable = lib.mkForce false;

  # Fix stateVersion conflict - use installer version
  system.stateVersion = lib.mkForce "26.05";
}
