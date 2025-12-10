{
  lib,
  pkgs,
  config,
  inputs,
  modulesPath,
  ...
}: let
  hostName = "installer-minimal";
  repoPath = inputs.self;
  authorizedKeysFile = ../installer/authorized_keys;
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

  system.activationScripts.installerWelcome = ''
    cat > /etc/issue << 'EOF'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║  NixOS Minimal Installation Environment                       ║
    ║  Fast, lightweight installer for testing                      ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

    Configuration: /per/etc/nixos

    Quick Start:
      1. Run: install-nixos
      2. Follow interactive prompts
      3. Reboot into your new system

    Note: This is the minimal ISO - essential tools only.
    For full recovery environment, use installer-iso-full.

    Documentation:
      • nixos-install-info    - Show installation options
      • install-nixos --help  - Show all installation flags

    Network:
      • SSH enabled (if authorized_keys configured)
      • NetworkManager available: nmtui

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

      # Terminal multiplexers
      tmux
    ])
    ++ [
      inputs.nixos-wizard.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.install-nixos
    ];

  environment.sessionVariables = {
    NIXOS_CONFIG_ROOT = "/per/etc/nixos";
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

  # Create netrc file for GitHub API authentication
  sops.templates."nix/netrc" = {
    content = ''
      machine github.com
      login token
      password ${config.sops.placeholder."github/token"}

      machine api.github.com
      login token
      password ${config.sops.placeholder."github/token"}
    '';
    path = "/etc/nix/netrc";
    mode = lib.mkForce "0444"; # World-readable in installer environment
  };

  nix.settings.netrc-file = config.sops.templates."nix/netrc".path;

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
