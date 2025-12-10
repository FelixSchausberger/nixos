{
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}: let
  hostName = "installer-minimal";
  repoPath = inputs.self;
  authorizedKeysFile = ../installer/authorized_keys;
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
    "d /per/system 0755 root root -"
  ];

  system.activationScripts.installRepo = ''
    mkdir -p /per/etc
    ln -sfn ${repoPath} /per/etc/nixos
  '';

  system.activationScripts.installerWelcome = ''
    cat > /etc/issue << 'EOF'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║  NixOS Minimal Installation Environment                       ║
    ║  Fast, lightweight installer for testing                      ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

    Configuration: /per/etc/nixos

    Installation Steps:
      1. Configure network (if needed): nmtui
      2. Export GitHub token:
         export NIX_CONFIG="access-tokens = github.com=YOUR_TOKEN"
      3. Install: cd /per/etc/nixos && nh os switch
      4. Reboot into your new system

    Alternative: Install via SSH from dev machine
      ssh root@<this-ip> and run the same commands

    Note: This is the minimal ISO - essential tools only.
    For full recovery environment, use installer-iso-full.

    Network:
      • SSH enabled (if authorized_keys configured)
      • NetworkManager available: nmtui
      • Find IP: ip addr show

    EOF
  '';

  # Minimal package set - ONLY installation essentials
  environment.systemPackages =
    (with pkgs; [
      # Essential editors
      vim
      nano

      # Disk tools
      parted
      gptfdisk

      # Network tools
      curl
      wget

      # Installation tools
      git
      nh

      # Terminal multiplexers
      tmux
    ])
    ++ [
      inputs.nixos-wizard.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  environment.sessionVariables = {
    NIXOS_CONFIG_ROOT = "/per/etc/nixos";
    GIT_AUTHOR_NAME = "NixOS Installer";
    GIT_AUTHOR_EMAIL = "installer@nixos.local";
    GIT_COMMITTER_NAME = "NixOS Installer";
    GIT_COMMITTER_EMAIL = "installer@nixos.local";
  };

  # GitHub authentication handled via environment variable at runtime
  # No secrets embedded in ISO - user provides token via NIX_CONFIG

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  security.sudo-rs.enable = lib.mkForce false;
  system.stateVersion = lib.mkForce "26.05";

  image.fileName = "nixos-installer-minimal.iso";
  isoImage = {
    volumeID = "NIXOS_MIN";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
}
