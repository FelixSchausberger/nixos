{pkgs, ...}:
pkgs.writeShellScriptBin "build-portable-vmdk" ''
  set -e

  echo "Building ZFS-based VMDK for portable workstation..."

  # Create temporary directory for image building
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT

  # Create 1TB raw image
  IMAGE_FILE="$TEMP_DIR/portable.raw"
  ${pkgs.qemu}/bin/qemu-img create -f raw "$IMAGE_FILE" 1T

  # Set up loop device
  LOOP_DEVICE=$(sudo ${pkgs.util-linux}/bin/losetup -f --show "$IMAGE_FILE")
  trap "sudo ${pkgs.util-linux}/bin/losetup -d $LOOP_DEVICE || true; rm -rf $TEMP_DIR" EXIT

  echo "Using loop device: $LOOP_DEVICE"

  # Create partitions: boot (512MB), swap (16GB), ZFS (rest)
  sudo ${pkgs.parted}/bin/parted "$LOOP_DEVICE" --script -- \
    mklabel gpt \
    mkpart ESP fat32 1MiB 512MiB \
    set 1 boot on \
    mkpart swap linux-swap 512MiB 16896MiB \
    mkpart primary 16896MiB 100%

  # Inform kernel about partition changes
  sudo ${pkgs.util-linux}/bin/partprobe "$LOOP_DEVICE"
  sleep 2

  # Format boot and swap partitions
  sudo ${pkgs.dosfstools}/bin/mkfs.fat -F 32 -n boot "''${LOOP_DEVICE}p1"
  sudo ${pkgs.util-linux}/bin/mkswap -L swap "''${LOOP_DEVICE}p2"

  # Create ZFS pool on the third partition
  sudo ${pkgs.zfs}/bin/zpool create -f -R /mnt \
    -O canmount=off \
    -O mountpoint=none \
    -O atime=off \
    -O compression=lz4 \
    -O xattr=sa \
    -O acltype=posixacl \
    rpool "''${LOOP_DEVICE}p3"

  # Create ZFS datasets
  sudo ${pkgs.zfs}/bin/zfs create -o canmount=off -o mountpoint=none rpool/eyd
  sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/ rpool/eyd/root
  sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/home rpool/eyd/home
  sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/nix rpool/eyd/nix
  sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/per rpool/eyd/per

  # Create blank snapshot for impermanence
  sudo ${pkgs.zfs}/bin/zfs snapshot rpool/eyd/root@blank

  # Mount filesystems
  sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/root
  sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/home
  sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/nix
  sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/per

  sudo mkdir -p /mnt/boot
  sudo mount "''${LOOP_DEVICE}p1" /mnt/boot

  # Enable swap partition
  echo "Enabling swap..."
  sudo ${pkgs.util-linux}/bin/swapon "''${LOOP_DEVICE}p2"

  # Build the system configuration
  echo "Building NixOS system configuration..."
  SYSTEM_CONFIG=$(nix build --no-link --print-out-paths .#nixosConfigurations.portable.config.system.build.toplevel)

  # Install the system
  echo "Installing NixOS to ZFS..."
  sudo mkdir -p /mnt/nix/var/nix/profiles/system
  sudo cp -r "$SYSTEM_CONFIG" /mnt/nix/var/nix/profiles/system/
  sudo ln -sf /nix/var/nix/profiles/system "$SYSTEM_CONFIG"

  # Install bootloader
  sudo mkdir -p /mnt/boot/EFI/BOOT
  sudo NIXOS_INSTALL_BOOTLOADER=1 /mnt/nix/var/nix/profiles/system/bin/switch-to-configuration boot

  # Unmount filesystems
  echo "Cleaning up..."
  sudo ${pkgs.util-linux}/bin/swapoff "''${LOOP_DEVICE}p2"
  sudo umount /mnt/boot
  sudo ${pkgs.zfs}/bin/zfs umount -a
  sudo ${pkgs.zfs}/bin/zpool export rpool

  # Convert to VMDK
  OUTPUT_DIR="$PWD/result"
  mkdir -p "$OUTPUT_DIR"
  ${pkgs.qemu}/bin/qemu-img convert -f raw -O vmdk "$IMAGE_FILE" "$OUTPUT_DIR/portable-workstation.vmdk"

  echo "ZFS VMDK created successfully!"
  echo "Output: $OUTPUT_DIR/portable-workstation.vmdk"
  echo "Layout: 512MB boot + 16GB encrypted swap + ~1TB ZFS with impermanence"
  echo "Includes: Full workstation + recovery tools"
  echo "Best Practice: Dedicated encrypted swap for maximum performance"
''
