let
  hostLib = import ../lib.nix;
  wms = ["hyprland"];
in {
  imports =
    [
      ../shared.nix
      ./boot-zfs.nix
      # ./hardware-configuration.nix  # TODO: Create hardware configuration
    ]
    ++ hostLib.wmModules wms;

  # Host-specific configuration
  hostConfig = {
    hostName = "portable";
    user = "schausberger";
    wm = wms;
    system = "x86_64-linux";
  };

  # Platform configuration (usually in hardware-configuration.nix)
  nixpkgs.hostPlatform = "x86_64-linux";

  # Basic file system configuration (normally in hardware-configuration.nix)
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Essential hardware support for portable use
  hardware = {
    # Better GPU compatibility
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    # Support for various graphics cards - NVIDIA configuration disabled for now
    # nvidia = {
    #   modesetting.enable = true;
    #   open = true;  # Use open source kernel modules for RTX/GTX 16xx series
    # };
  };

  # Support for ZFS datasets
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    # ZFS auto-mounting is handled by boot configuration
  };

  # X server configuration disabled for Hyprland-only setup
  # services.xserver = {
  #   # Support for common GPUs
  #   videoDrivers = ["modesetting" "nvidia" "intel" "amdgpu"];
  # };

  # Recovery tools and scripts
  system.activationScripts.rescueScripts = ''
    mkdir -p /usr/local/bin

    # Create recovery script for your thinkpad
    cat > /usr/local/bin/recover-thinkpad << 'EOF'
    #!/bin/bash
    set -e

    echo "ThinkPad Recovery Script"
    echo "========================"

    # Decrypt with your physical presence (for thinkpad only)
    if ! blkid | grep -q luks-rpool; then
      echo "Decrypting LUKS partition..."
      cryptsetup luksOpen /dev/disk/by-id/nvme-SAMSUNG_MZVL4512HBLU-00BL7_S67VNF0TA81898-part2 luks-rpool
    fi

    # Create mount point
    mkdir -p /mnt

    # Import and mount ZFS
    echo "Importing ZFS pool..."
    zpool import -f -R /mnt rpool || echo "Pool already imported or not available"

    # Mount filesystems
    echo "Mounting filesystems..."
    mount -t zfs rpool/eyd/root /mnt || echo "Root already mounted or not available"
    mkdir -p /mnt/{nix,per,home,boot}
    mount -t zfs rpool/eyd/nix /mnt/nix || echo "Nix already mounted or not available"
    mount -t zfs rpool/eyd/per /mnt/per || echo "Per already mounted or not available"
    mount -t zfs rpool/eyd/home /mnt/home || echo "Home already mounted or not available"
    mount /dev/disk/by-id/nvme-SAMSUNG_MZVL4512HBLU-00BL7_S67VNF0TA81898-part1 /mnt/boot || echo "Boot already mounted or not available"

    # Mount special filesystems
    mount --rbind /dev /mnt/dev
    mount --rbind /proc /mnt/proc
    mount --rbind /sys /mnt/sys

    echo ""
    echo "System mounted at /mnt. You can now:"
    echo "1. Run 'nixos-enter' to get a shell"
    echo "2. Run 'nixos-rebuild switch --flake /mnt/path/to/flake#thinkpad' to rebuild"
    echo "3. Or manually chroot with: chroot /mnt /bin/bash"
    EOF

    # Add similar scripts for other hosts
    chmod +x /usr/local/bin/recover-thinkpad
  '';
}
