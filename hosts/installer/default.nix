{
  lib,
  pkgs,
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
    "d /per/system 0755 root root -"
  ];

  system.activationScripts.installRepo = ''
    mkdir -p /per/etc
    ln -sfn ${repoPath} /per/etc/nixos
  '';

  # Pre-configure installation environment
  system.activationScripts.installerWelcome = ''
    cat > /etc/issue << 'EOF'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║  NixOS Installation Environment (Full)                        ║
    ║  Complete recovery and installation tools                     ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

    Configuration: /per/etc/nixos

    Installation Steps:
      1. Configure network (if needed): nmtui
      2. Export GitHub token:
         export NIX_CONFIG="access-tokens = github.com=YOUR_TOKEN"
      3. Install (specify your hostname):
         sudo nixos-rebuild switch --flake .#hp-probook-vmware
         (or: nh os switch .#hp-probook-vmware)
      4. Reboot into your new system

    Available hosts: desktop, surface, portable, hp-probook-vmware

    Alternative: Install via SSH from dev machine
      ssh root@<this-ip> and run the same commands

    Note: This is the full ISO with GUI and comprehensive recovery tools.
    For lightweight testing, use installer-iso-minimal.

    Network:
      • SSH enabled (if authorized_keys configured)
      • NetworkManager available: nmtui
      • Find IP: ip addr show

    EOF
  '';

  # Ensure the portable scripts know where the configuration lives
  environment.sessionVariables = {
    NIXOS_CONFIG_ROOT = "/per/etc/nixos";
    # Pre-configure git for potential operations
    GIT_AUTHOR_NAME = "NixOS Installer";
    GIT_AUTHOR_EMAIL = "installer@nixos.local";
    GIT_COMMITTER_NAME = "NixOS Installer";
    GIT_COMMITTER_EMAIL = "installer@nixos.local";
  };

  # GitHub authentication handled via environment variable at runtime
  # No secrets embedded in ISO - user provides token via NIX_CONFIG

  # Additional packages for installation convenience
  environment.systemPackages = with pkgs; [
    # Network diagnostics
    dnsutils
    inetutils
    whois

    # Text editors (in case user needs to edit configs)
    vim
    nano

    # Installation tools
    git
    nh

    # Disk utilities beyond basic recovery tools
    parted
    gptfdisk

    # Convenience
    tmux
    screen
  ];

  # Enable SSH for remote installation
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

  # Enable NetworkManager for easier network setup
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false; # Disable wpa_supplicant in favor of NetworkManager

  # Fix sudo conflict between installation-device.nix and sudo-rs.nix
  # Keep security.sudo (from installation-device) and disable sudo-rs
  security.sudo-rs.enable = lib.mkForce false;

  # Fix stateVersion conflict - use installer version
  system.stateVersion = lib.mkForce "26.05";

  # ISO customization
  image.fileName = "nixos-installer-full.iso";
  isoImage = {
    volumeID = "NIXOS_FULL";

    # Make ISO bootable in UEFI and BIOS modes
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
}
