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

  # Optional SSH key files for baking into ISO
  # Place your keys in hosts/installer/ssh_keys/ (gitignored for security)
  sshKeyDir = ../installer/ssh_keys;
  hasSshKeys = builtins.pathExists sshKeyDir;
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
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

  # Disable persistence for live ISO (no persistent filesystem)
  environment.persistence = lib.mkForce {};

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

  users.users = {
    root = {
      password = "nixos"; # Default password for installer convenience
      openssh.authorizedKeys.keyFiles =
        lib.optionals hasAuthorizedKeys [authorizedKeysFile];
    };

    # Override schausberger user for ISO (empty password, no sops)
    schausberger = {
      hashedPasswordFile = lib.mkForce null;
      password = ""; # Empty password for easy ISO login
    };
  };

  # Auto-login as schausberger on TTY1
  services.getty.autologinUser = lib.mkForce "schausberger";

  systemd.tmpfiles.rules = [
    "d /per 0755 root root -"
    "d /per/etc 0755 root root -"
    "d /per/system 0755 root root -"
    "d /per/home 0755 root root -"
    "d /per/home/schausberger 0755 schausberger users -"
    "d /per/home/schausberger/.ssh 0700 schausberger users -"
  ];

  system.activationScripts.installRepo = ''
    mkdir -p /per/etc
    ln -sfn ${repoPath} /per/etc/nixos
  '';

  # Copy SSH keys to persistent location if they exist in the ISO
  system.activationScripts.installSshKeys = lib.mkIf hasSshKeys ''
    mkdir -p /per/home/schausberger/.ssh
    ${lib.optionalString (builtins.pathExists (sshKeyDir + "/id_ed25519")) ''
      cp ${sshKeyDir}/id_ed25519 /per/home/schausberger/.ssh/id_ed25519
      chmod 600 /per/home/schausberger/.ssh/id_ed25519
    ''}
    ${lib.optionalString (builtins.pathExists (sshKeyDir + "/id_ed25519.pub")) ''
      cp ${sshKeyDir}/id_ed25519.pub /per/home/schausberger/.ssh/id_ed25519.pub
      chmod 644 /per/home/schausberger/.ssh/id_ed25519.pub
    ''}
    chown -R schausberger:users /per/home/schausberger/.ssh
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
      2. Option A - Remote install (recommended for VMs):
         Set root password: passwd
         Get IP: ip addr show
         From dev machine:
           nix run github:nix-community/nixos-anywhere -- \
             --flake .#hostname root@<this-ip>
      3. Option B - Local install from this ISO:
         a. Create GitHub token (required for flake inputs):
            Visit: https://github.com/settings/tokens/new
            Scopes: NONE needed (just for public repo access)
            Expiration: 7 days (temporary)
         b. Set up configuration:
            cp -r /per/etc/nixos /tmp/nixos-config
            cd /tmp/nixos-config
            ln -sf config-installer.nix config.nix
         c. Install with GitHub authentication:
            export NIX_CONFIG="access-tokens = github.com=$YOUR_TOKEN"
            sudo -E nixos-rebuild switch --flake .#hostname
            (Note: -E flag preserves environment)
      4. Reboot into your new system

    Available hosts: desktop, surface, portable, hp-probook-vmware

    Alternative: Install via SSH from dev machine
      ssh root@<this-ip> and run the same commands

    Note: This is the minimal ISO - essential tools only.
    For full recovery environment, use installer-iso-full.

    Network:
      • SSH enabled with password and key authentication
      • Root password: nixos
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

  # FlakeHub disabled during installation via config-installer.nix
  # User symlinks config.nix -> config-installer.nix temporarily
  # Deployed system uses FlakeHub normally (config.nix is in /nix/store, not affected by symlink)

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true; # Allow password auth for installer convenience
    };
  };

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  networking.wireless.iwd.enable = lib.mkForce false; # Disable IWD on installer (wired-only)

  security.sudo-rs.enable = lib.mkForce false;
  system.stateVersion = lib.mkForce "26.05";

  image.fileName = "nixos-installer-minimal.iso";
  isoImage = {
    volumeID = "NIXOS_MIN";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
}
