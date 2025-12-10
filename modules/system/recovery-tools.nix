{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
  hostUser =
    if config ? hostConfig && config.hostConfig ? user
    then config.hostConfig.user
    else defaults.system.user;
in {
  environment.systemPackages =
    (with pkgs; [
      # Essential recovery tools
      gparted
      testdisk
      ddrescue
      cryptsetup
      zfs

      # Network tools
      curl
      wget
      rsync
      openssh

      # Filesystem tools
      ntfs3g
      exfat
      e2fsprogs
      btrfs-progs

      # Hardware tools
      pciutils
      usbutils
      hdparm
      smartmontools

      # System tools
      htop
      iotop
      tree
      file

      # Development basics
      git
      vim

      # Image creation / virtualization helpers
      qemu_full

      # Workstation + collaboration
      firefox
      vscode
      discord

      # Development toolchains
      docker
      docker-compose
      nodejs
      python3
      rustup
      go

      # Terminal utilities
      tmux
      fzf
      ripgrep
      fd
      bat
      eza

      # Media & graphics
      vlc
      gimp

      # Office & archives
      libreoffice
      p7zip
      unzip

      # Installation tools
      nh
    ])
    ++ [
      inputs.nixos-wizard.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.userServices = true;
  };

  services.printing = {
    enable = true;
    drivers = [pkgs.hplip];
  };

  system.activationScripts.recoveryTools = ''
    mkdir -p /usr/local/bin

    # Create generic recovery script that auto-detects systems
    cat > /usr/local/bin/nixos-recover << 'EOF'
    #!/usr/bin/env bash
    set -e

    echo "NixOS Recovery Tool"
    echo "=================="
    echo "Auto-detecting NixOS installations..."

    # Function to mount a discovered system
    mount_nixos_system() {
        local zfs_part="$1"
        local boot_part="$2"
        local pool_name="$3"
        local is_encrypted="$4"

        echo "Found NixOS system:"
        echo "  ZFS partition: $zfs_part"
        echo "  Boot partition: $boot_part"
        echo "  Pool name: $pool_name"
        echo "  Encrypted: $is_encrypted"
        echo

        # Handle encryption
        if [[ "$is_encrypted" == "true" ]]; then
            echo "Decrypting LUKS partition..."
            if ! cryptsetup status luks-rpool >/dev/null 2>&1; then
                cryptsetup luksOpen "$zfs_part" luks-rpool
            fi
        fi

        # Import ZFS pool
        echo "Importing ZFS pool $pool_name..."
        if ! zpool list "$pool_name" >/dev/null 2>&1; then
            zpool import -f -R /mnt "$pool_name"
        fi

        # Mount filesystems
        echo "Mounting filesystems..."
        mkdir -p /mnt
        mount -t zfs "$pool_name/eyd/root" /mnt 2>/dev/null || echo "Root filesystem already mounted"

        mkdir -p /mnt/{boot,nix,home,per}
        mount "$boot_part" /mnt/boot 2>/dev/null || echo "Boot already mounted"
        mount -t zfs "$pool_name/eyd/nix" /mnt/nix 2>/dev/null || echo "Nix already mounted"
        mount -t zfs "$pool_name/eyd/home" /mnt/home 2>/dev/null || echo "Home already mounted"
        mount -t zfs "$pool_name/eyd/per" /mnt/per 2>/dev/null || echo "Persist already mounted"

        # Mount virtual filesystems
        mount --rbind /dev /mnt/dev 2>/dev/null || true
        mount --rbind /proc /mnt/proc 2>/dev/null || true
        mount --rbind /sys /mnt/sys 2>/dev/null || true

        echo
        echo "✅ System successfully mounted at /mnt"
        echo "Next steps:"
        echo "1. Enter system: nixos-enter"
        echo "2. Rebuild: nixos-rebuild switch --flake /mnt/per/etc/nixos#hostname"
        echo "3. Or chroot manually: chroot /mnt"
    }

    # Auto-detect NixOS installations
    detect_nixos() {
        echo "Scanning for NixOS installations..."

        for disk in /dev/sd? /dev/nvme?n?; do
            [[ -b "$disk" ]] || continue
            echo "Checking $disk..."

            # Look for ZFS partitions
            for part in "$disk"*; do
                [[ -b "$part" ]] || continue

                # Check if it's a ZFS partition
                if blkid "$part" | grep -q zfs_member; then
                    echo "Found ZFS partition: $part"

                    # Try to get pool name
                    local pool_name=$(zdb -l "$part" 2>/dev/null | grep -E "name: 'rpool" | head -1 | sed "s/.*name: '//" | sed "s/'.*//")

                    if [[ -n "$pool_name" ]]; then
                        # Find corresponding boot partition (usually partition 1)
                        local boot_part="''${disk}1"
                        [[ -b "$boot_part" ]] || continue

                        # Check if encrypted
                        local is_encrypted="false"
                        if blkid "$part" | grep -q crypto_LUKS; then
                            is_encrypted="true"
                        fi

                        echo "Do you want to mount this system? [y/N]"
                        read -r response
                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            mount_nixos_system "$part" "$boot_part" "$pool_name" "$is_encrypted"
                            return 0
                        fi
                    fi
                fi
            done
        done

        echo "No NixOS installations found or none selected."
        return 1
    }

    # Main execution
    if [[ $# -eq 0 ]]; then
        detect_nixos
    else
        echo "Usage: nixos-recover"
        echo "This tool auto-detects and mounts NixOS installations for recovery."
    fi
    EOF

    chmod +x /usr/local/bin/nixos-recover

    # Installation info script
    cat > /usr/local/bin/nixos-install-info << 'EOF'
    #!/usr/bin/env bash

    echo "NixOS Installation Information"
    echo "=============================="
    echo
    echo "This system uses disko for declarative disk management."
    echo
    echo "Installation workflow:"
    echo "  1. Configure network (if needed): nmtui"
    echo "  2. Export GitHub token:"
    echo "     export NIX_CONFIG=\"access-tokens = github.com=YOUR_TOKEN\""
    echo "  3. Install: cd /per/etc/nixos && nh os switch"
    echo "  4. Reboot into your new system"
    echo
    echo "Alternative: Install via SSH from dev machine"
    echo "  ssh root@<this-ip> and run the same commands"
    echo
    echo "Available hosts:"
    echo "  • desktop           - Desktop PC with AMD RX 6700XT"
    echo "  • surface           - Surface tablet/laptop"
    echo "  • portable          - Portable/recovery with ZFS"
    echo "  • hp-probook-vmware - VMware VM"
    echo
    echo "Documentation:"
    echo "  https://github.com/FelixSchausberger/nixos/wiki/Installation"
    EOF

    chmod +x /usr/local/bin/nixos-install-info
  '';

  networking = {
    networkmanager.enable = true;
    firewall.enable = lib.mkForce false;
  };

  users.users.rescue = {
    isNormalUser = true;
    description = "Recovery User";
    extraGroups = [
      "wheel"
      "networkmanager"
      "disk"
    ];
  };

  users.users.${hostUser}.extraGroups = ["docker"];

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = false;
    };

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
      };
    };
  };

  programs.dconf.enable = true;
}
