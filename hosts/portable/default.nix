# Portable recovery ISO: a TUI-first live USB image with ZFS support and the
# disk-recovery tool suite. Built as packages.installer-iso-portable.
#
# This is deliberately not a nixosConfiguration: it boots a live squashfs
# environment, has no persistent root, and is never converged by comin. The
# deployed fleet lives in nixosConfigurations (see hosts/default.nix).
{
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}: let
  hostName = "portable";
  authorizedKeysFile = ../installer/authorized_keys;
  hasAuthorizedKeys = builtins.pathExists authorizedKeysFile;
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
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
    wms = [];
  };

  # Isolate from removed nixpkgs aliases that would otherwise throw during
  # ISO evaluation (same workaround as the installer images).
  nixpkgs.config.allowAliases = false;
  nixpkgs.overlays = [
    (final: _prev: {
      nixfmt-classic = final.nixfmt;
      nixfmt-rfc-style = final.nixfmt;
    })
    # ceph pulls python311 and breaks evaluation on current nixpkgs; the ISO
    # does not need ceph-enabled qemu.
    (_final: prev: {
      qemu = prev.qemu.override {ceph = null;};
    })
  ];

  # Live ISO: no persistent filesystem.
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
      hashedPassword = lib.mkForce null;
      password = "nixos";
      openssh.authorizedKeys.keyFiles =
        lib.optionals hasAuthorizedKeys [authorizedKeysFile];
    };

    schausberger = {
      hashedPasswordFile = lib.mkForce null;
      password = "";
    };
  };

  services.getty.autologinUser = lib.mkForce "schausberger";

  systemd.tmpfiles.rules = [
    "d /per 0755 root root -"
    "d /per/etc 0755 root root -"
    "d /per/system 0755 root root -"
  ];

  system.activationScripts.installRepo = ''
    mkdir -p /per/etc
    ln -sfn ${inputs.self} /per/etc/nixos
  '';

  system.activationScripts.portableWelcome = ''
    cat > /etc/issue << 'EOF'

    NixOS Portable Recovery Environment
    TUI-only live image with ZFS and disk-recovery tooling.

    Configuration: /per/etc/nixos
    Deployed hosts: desktop, hp-probook-wsl, m920q

    EOF
  '';

  environment.systemPackages = with pkgs; [
    vim
    nano
    parted
    gptfdisk
    curl
    wget
    git
    tmux
  ];

  environment.sessionVariables = {
    NIXOS_CONFIG_ROOT = "/per/etc/nixos";
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      # recovery-tools.nix hardens this to false; the live image wants
      # password auth for convenience, matching the installer ISOs.
      PasswordAuthentication = lib.mkForce true;
    };
  };

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  networking.wireless.iwd.enable = lib.mkForce false;

  security.sudo-rs.enable = lib.mkForce false;
  system.stateVersion = lib.mkForce "26.05";

  image.fileName = "nixos-portable.iso";
  isoImage = {
    volumeID = "NIXOS_PORTABLE";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
}
