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
  # Embed age key for sops decryption in installer
  sopsKeyFile = ../../secrets/sops-key.txt;
  hasSopsKey = builtins.pathExists sopsKeyFile;
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

  # Embed age key for sops-nix to decrypt secrets during installation
  system.activationScripts.installSopsKey = lib.mkIf hasSopsKey ''
    mkdir -p /per/system
    cp ${sopsKeyFile} /per/system/sops-key.txt
    chmod 600 /per/system/sops-key.txt
  '';

  # Pre-configure installation environment
  system.activationScripts.installerWelcome = ''
    cat > /etc/issue << 'EOF'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║  NixOS Installation Environment                               ║
    ║  Ready to install your system                                 ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

    Configuration: /per/etc/nixos

    Quick Start:
      1. Run: install-nixos
      2. Follow interactive prompts
      3. Reboot into your new system

    Documentation:
      • nixos-install-info    - Show installation options
      • install-nixos --help  - Show all installation flags

    Network:
      • SSH enabled (if authorized_keys configured)
      • NetworkManager available: nmtui

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

  # Configure GitHub token for flake evaluation during installation
  # This avoids rate limit issues when disko-install evaluates the flake
  sops.secrets."github/token" = {
    sopsFile = ../../secrets/secrets.yaml;
    mode = "0444"; # World-readable since it's in a temporary installer environment
  };

  nix.settings.access-tokens = lib.mkForce [
    "github.com=/run/secrets/github/token"
  ];

  # Additional packages for installation convenience
  environment.systemPackages = with pkgs; [
    # Network diagnostics
    dnsutils
    inetutils
    whois

    # Text editors (in case user needs to edit configs)
    vim
    nano

    # Git for repo operations
    git

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
