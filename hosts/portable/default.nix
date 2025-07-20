{
  config,
  pkgs,
  lib,
  ...
}: let
  hostLib = import ../lib.nix;
  wms = ["hyprland"];
in {
  imports =
    [
      ../shared.nix
      ./hardware-configuration.nix
    ]
    ++ hostLib.wmModules wms;

  hostConfig = {
    hostName = "portable";
    user = "schausberger";
    wm = wms;
    system = "x86_64-linux";
  };

  # Hardware compatibility enhancements for portable use
  boot.kernelParams = [
    "nohibernate"
    # Add parameters for better hardware compatibility
    "i915.force_probe=*" # Force Intel GPU drivers
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Better NVIDIA compatibility
    "usbcore.autosuspend=-1" # Prevent USB devices from auto-suspending
  ];

  # Extra kernel modules for better hardware compatibility
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback # For virtual webcam support
    # Note: broadcom_sta removed due to security issues (CVE-2019-9501, CVE-2019-9502)
    # rtl8821au # Common WiFi driver - removed due to potential compatibility issues
    # rtl8821cu # Common WiFi driver - removed due to potential compatibility issues
  ];

  # Load additional kernel modules for better hardware compatibility
  boot.kernelModules = [
    "v4l2loopback"
    # Common hardware support
    "thunderbolt"
    "uvcvideo"
    "hid_multitouch"
  ];

  # Essential hardware support for portable use
  hardware = {
    # Better GPU compatibility
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  # Recovery and workstation tools for portable system
  environment.systemPackages = with pkgs; [
    # Essential recovery tools
    gparted # Disk partitioning GUI
    testdisk # Data recovery
    ddrescue # Data recovery from damaged disks
    cryptsetup # LUKS encryption management
    zfs # ZFS management

    # Network tools
    curl
    wget
    rsync
    openssh

    # File system tools
    ntfs3g # NTFS support
    exfat # exFAT support
    e2fsprogs # ext2/3/4 tools
    btrfs-progs # Btrfs tools

    # Hardware tools
    pciutils # lspci
    usbutils # lsusb
    hdparm # Hard disk parameters
    smartmontools # SMART disk monitoring

    # System tools
    htop # Process monitor
    iotop # I/O monitor
    tree # Directory tree
    file # File type detection

    # Development tools for recovery
    git # Version control
    vim # Text editor

    # Image creation tools
    qemu_full # For VMDK creation and testing

    # Workstation tools for portable development
    firefox # Web browser
    vscode # IDE
    discord # Communication

    # Development tools
    docker # Containerization
    docker-compose # Container orchestration
    nodejs # JavaScript runtime
    python3 # Python interpreter
    rustup # Rust toolchain
    go # Go language

    # Additional system tools for workstation use
    tmux # Terminal multiplexer
    fzf # Fuzzy finder
    ripgrep # Fast grep
    fd # Fast find
    bat # Better cat
    eza # Better ls

    # Media tools
    vlc # Video player
    gimp # Image editor

    # Office tools
    libreoffice # Office suite

    # Archive tools
    p7zip # 7zip support
    unzip # ZIP support
  ];

  # Enable services for workstation + recovery
  services = {
    openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
      # Disable password auth by default for security
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };

    # Network discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish.enable = true;
      publish.userServices = true;
    };

    # Printing support (useful for portable workstation)
    printing = {
      enable = true;
      drivers = [pkgs.hplip]; # HP printer support
    };
  };

  # Recovery scripts and tools
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

        mkdir -p /mnt/{boot,nix,home,persist}
        mount "$boot_part" /mnt/boot 2>/dev/null || echo "Boot already mounted"
        mount -t zfs "$pool_name/eyd/nix" /mnt/nix 2>/dev/null || echo "Nix already mounted"
        mount -t zfs "$pool_name/eyd/home" /mnt/home 2>/dev/null || echo "Home already mounted"
        mount -t zfs "$pool_name/eyd/per" /mnt/persist 2>/dev/null || echo "Persist already mounted"

        # Mount virtual filesystems
        mount --rbind /dev /mnt/dev 2>/dev/null || true
        mount --rbind /proc /mnt/proc 2>/dev/null || true
        mount --rbind /sys /mnt/sys 2>/dev/null || true

        echo
        echo "✅ System successfully mounted at /mnt"
        echo "Next steps:"
        echo "1. Enter system: nixos-enter"
        echo "2. Rebuild: nixos-rebuild switch --flake /mnt/persist/etc/nixos#hostname"
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

    # Create VMDK installer script
    cat > /usr/local/bin/create-nixos-installer << 'EOF'
    #!/usr/bin/env bash
    set -e

    echo "NixOS VMDK Image Builder"
    echo "======================="

    # Change to the nixos config directory
    cd /per/etc/nixos 2>/dev/null || cd /persist/etc/nixos 2>/dev/null || {
        echo "Error: Could not find NixOS configuration directory"
        echo "Expected: /per/etc/nixos or /persist/etc/nixos"
        exit 1
    }

    echo "Building installer ISO..."
    nix build .#installer-iso --print-out-paths

    echo "Building ZFS VMDK for portable workstation..."
    nix build .#vmdk-portable --print-out-paths

    echo
    echo "✅ Images built successfully!"
    echo "The portable VMDK now includes:"
    echo "  • ZFS with impermanence"
    echo "  • Full workstation capabilities"
    echo "  • All recovery tools preserved"
    echo "Find them in the result* directories"
    EOF

    chmod +x /usr/local/bin/create-nixos-installer

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
    echo "1. 🚀 VMDK Image Installation (Recommended)"
    echo "   - Fast, reliable, pre-configured"
    echo "   - Best for most users"
    echo
    echo "2. 🛠️ Custom ZFS Installation (Advanced)"
    echo "   - Full control over partitioning and encryption"
    echo "   - Uses the legacy ZFS setup tool"
    echo

    read -p "Choose installation method [1/2]: " choice

    case $choice in
        1)
            echo
            echo "📦 VMDK Workstation Installation Selected"
            echo "========================================"
            echo
            echo "This will install a ZFS-based NixOS workstation with:"
            echo "• Full development environment (VSCode, Docker, etc.)"
            echo "• Impermanence (clean state + selective persistence)"
            echo "• All recovery tools preserved"
            echo "• 1TB ZFS storage with snapshots"
            echo
            echo "Installation process:"
            echo "1. Build a fresh VMDK image with workstation configuration"
            echo "2. Write it to your target disk"
            echo "3. Set up ZFS bootloader"
            echo

            # List available disks
            echo "Available disks:"
            lsblk -d -o NAME,SIZE,MODEL | grep -v loop
            echo

            read -p "Enter target disk (e.g., /dev/sdb): " target_disk

            if [[ ! -b "$target_disk" ]]; then
                echo "❌ Disk $target_disk not found"
                exit 1
            fi

            echo
            echo "⚠️  WARNING: This will ERASE ALL DATA on $target_disk"
            read -p "Type 'YES' to continue: " confirm

            if [[ "$confirm" != "YES" ]]; then
                echo "Installation cancelled."
                exit 0
            fi

            echo
            echo "🔨 Building VMDK image..."
            create-nixos-installer

            echo
            echo "💾 Writing to disk $target_disk..."
            qemu-img convert -f vmdk -O raw result*/nixos.vmdk /tmp/nixos.raw
            dd if=/tmp/nixos.raw of="$target_disk" bs=1M status=progress

            echo
            echo "🚀 Setting up bootloader..."
            parted "$target_disk" set 1 boot on

            # Mount and install bootloader
            mkdir -p /mnt/temp
            mount "''${target_disk}1" /mnt/temp
            mount --bind /dev /mnt/temp/dev
            mount --bind /proc /mnt/temp/proc
            mount --bind /sys /mnt/temp/sys

            chroot /mnt/temp /nix/store/*/bin/grub-install --target=i386-pc "$target_disk"

            umount /mnt/temp/dev /mnt/temp/proc /mnt/temp/sys /mnt/temp
            rm -f /tmp/nixos.raw

            echo
            echo "✅ Installation complete!"
            echo "You can now boot from $target_disk"
            ;;

        2)
            echo
            echo "🛠️ Custom ZFS Installation Selected"
            echo "=================================="
            echo
            echo "This will launch the advanced ZFS setup tool."
            echo "You'll have full control over:"
            echo "- Disk partitioning"
            echo "- ZFS pool configuration"
            echo "- LUKS encryption options"
            echo "- Host-specific settings"
            echo

            read -p "Continue with custom installation? [y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "Installation cancelled."
                exit 0
            fi

            echo
            echo "Launching ZFS setup tool..."
            echo "Follow the prompts for custom installation."
            echo

            # Launch the ZFS setup tool
            zfs-nixos-setup --help
            echo
            echo "Example usage:"
            echo "zfs-nixos-setup --disk /dev/sdb --hostname myhost --username myuser"
            ;;

        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    EOF

    chmod +x /usr/local/bin/install-nixos-zfs
  '';

  # Network configuration for recovery scenarios
  networking = {
    networkmanager.enable = true; # NetworkManager for easy WiFi (includes wireless)
    firewall.enable = lib.mkForce false; # Disabled for recovery scenarios
  };

  # Additional user for recovery operations
  users.users.rescue = {
    isNormalUser = true;
    description = "Recovery User";
    extraGroups = [
      "wheel"
      "networkmanager"
      "disk"
    ];
    # No password set - use sudo passwd rescue to set one
  };

  # Add main user to docker group for development
  users.users.schausberger.extraGroups = ["docker"];

  # Virtualization for development and testing
  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = false; # Don't auto-start to save resources
    };

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
      };
    };
  };

  # Programs needed for workstation functionality
  programs = {
    # Enable dconf for GNOME apps
    dconf.enable = true;
  };

  # XDG portals for proper app integration
  xdg.portal = {
    enable = true;
    wlr.enable = true; # For Wayland/Hyprland
  };
}
