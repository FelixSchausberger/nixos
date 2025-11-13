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
    echo "Installation options:"
    echo "  1. Automated: Use 'install-nixos-zfs' command"
    echo "  2. Manual: See /per/etc/nixos/hosts/<hostname>/disko/disko.nix"
    echo
    echo "Documentation:"
    echo "  https://github.com/FelixSchausberger/nixos/wiki/Installation"
    echo "  (See 'Disko Configuration Guide' section)"
    EOF

    chmod +x /usr/local/bin/nixos-install-info

    # Create ZFS installation helper script
    cat > /usr/local/bin/install-nixos-zfs << 'EOF'
    #!/usr/bin/env bash
    set -e

    echo "NixOS ZFS Installation Helper"
    echo "============================"
    echo
    echo "This tool helps you install new ZFS-based NixOS systems."
    echo

    # Check if we're running from recovery system
    if [[ ! -f /usr/local/bin/nixos-recover ]]; then
        echo "❌ This script should be run from the NixOS recovery system"
        exit 1
    fi

    echo "Available installation methods:"
    echo
    echo "1. 🚀 Disko Automated Installation (Recommended)"
    echo "   - Declarative disk management with reproducible layouts"
    echo "   - Automated partitioning, formatting, and installation"
    echo "   - Best for most users"
    echo
    echo "2. 🛠️ Manual Disko Configuration (Advanced)"
    echo "   - Edit disko config for custom ZFS settings"
    echo "   - Full control over pool options and datasets"
    echo

    read -p "Choose installation method [1/2]: " choice

    case $choice in
        1)
            echo
            echo "📦 Disko Automated Installation Selected"
            echo "========================================"
            echo
            echo "This will install NixOS with declarative disk management:"
            echo "• Automated partitioning using disko configuration"
            echo "• ZFS with impermanence (for portable host)"
            echo "• Reproducible disk layout from Nix configuration"
            echo "• Full system installation in one command"
            echo
            echo "Installation process:"
            echo "1. Identify target disk"
            echo "2. Run disko-install with your host configuration"
            echo "3. Automatic partitioning, formatting, and NixOS installation"
            echo

            # List available disks
            echo "Available disks:"
            lsblk -d -o NAME,SIZE,MODEL | grep -v loop
            echo

            read -p "Enter target disk (e.g., /dev/sdb or /dev/nvme0n1): " target_disk

            if [[ ! -b "$target_disk" ]]; then
                echo "❌ Disk $target_disk not found"
                exit 1
            fi

            echo
            echo "Available host configurations:"
            echo "  • desktop  - Standard desktop with ext4 and swap"
            echo "  • surface  - Surface laptop with ext4 and 8GB swap"
            echo "  • portable - ZFS with impermanence and optional swap"
            echo
            read -p "Enter host name [portable]: " hostname
            hostname=''${hostname:-portable}

            echo
            echo "⚠️  WARNING: This will ERASE ALL DATA on $target_disk"
            echo "Installing host: $hostname"
            read -p "Type 'YES' to continue: " confirm

            if [[ "$confirm" != "YES" ]]; then
                echo "Installation cancelled."
                exit 0
            fi

            echo
            echo "🔨 Running disko-install..."
            echo "This will partition, format, and install NixOS..."
            echo

            cd /per/etc/nixos || {
                echo "❌ Could not find NixOS configuration directory"
                exit 1
            }

            nix run 'github:nix-community/disko#disko-install' -- \
              --flake ".#$hostname" \
              --disk main "$target_disk"

            echo
            echo "✅ Installation complete!"
            echo "You can now boot from $target_disk"
            echo
            echo "After first boot:"
            echo "  1. Set user password: passwd schausberger"
            echo "  2. Configure secrets (see Wiki: Secret Management)"
            ;;

        2)
            echo
            echo "🛠️ Manual Disko Configuration Selected"
            echo "======================================="
            echo
            echo "For advanced users who need custom ZFS configurations:"
            echo
            echo "Steps:"
            echo "1. Edit the disko configuration for your needs:"
            echo "   nano /per/etc/nixos/hosts/portable/disko/disko.nix"
            echo
            echo "2. Customize ZFS settings:"
            echo "   • Pool options (compression, encryption, etc.)"
            echo "   • Dataset hierarchy"
            echo "   • Swap partition (uncomment if needed)"
            echo
            echo "3. Run disko-install with your customized config:"
            echo "   nix run 'github:nix-community/disko#disko-install' -- \\"
            echo "     --flake '.#portable' \\"
            echo "     --disk main /dev/nvme0n1"
            echo
            echo "See the Wiki for full customization guide:"
            echo "  https://github.com/FelixSchausberger/nixos/wiki/Installation"
            echo "  (Disko Configuration Guide section)"
            ;;

        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    EOF

    chmod +x /usr/local/bin/install-nixos-zfs
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
