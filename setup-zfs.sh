#!/usr/bin/env bash
# zfs nixos setup script - general purpose script for setting up nixos with zfs
# this can be used for any host, including external drives or internal disks

set -e

# default values
disk=""
hostname="nixos"
username="$(whoami)"
swapsize=4            # size in gb
efi_size=1            # size in gb
reserve=1             # space to leave at end of disk in gb
encryption=false
use_swap=true
allow_discard=true    # enable trim/discard for ssd

# help function
print_help() {
    echo "zfs nixos setup script"
    echo "usage: $0 [options]"
    echo ""
    echo "options:"
    echo "  -d, --disk disk           disk to use (required)"
    echo "  -h, --hostname hostname   hostname to use (default: nixos)"
    echo "  -u, --username username   username to use (default: current user)"
    echo "  -s, --swap size           swap size in gb (default: 4, use 0 for no swap)"
    echo "  -e, --efi size            efi partition size in gb (default: 1)"
    echo "  -r, --reserve size        reserve space at end of disk in gb (default: 1)"
    echo "  -e, --encrypt             enable luks encryption"
    echo "  -n, --no-swap             don't create swap partition"
    echo "  -t, --no-trim             disable trim/discard (for non-ssd)"
    echo "  --help                    display this help message"
    echo ""
    echo "example:"
    echo "  $0 -d /dev/sda -h thinkpad -u john -s 8 -e"
    echo ""
    exit 0
}

# parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--disk)
            disk="$2"
            shift 2
            ;;
        -h|--hostname)
            hostname="$2"
            shift 2
            ;;
        -u|--username)
            username="$2"
            shift 2
            ;;
        -s|--swap)
            swapsize="$2"
            shift 2
            ;;
        -e|--efi)
            efi_size="$2"
            shift 2
            ;;
        -r|--reserve)
            reserve="$2"
            shift 2
            ;;
        -e|--encrypt)
            encryption=true
            shift
            ;;
        -n|--no-swap)
            use_swap=false
            shift
            ;;
        -t|--no-trim)
            allow_discard=false
            shift
            ;;
        --help)
            print_help
            ;;
        *)
            echo "unknown option: $1"
            print_help
            ;;
    esac
done

# check for required commands
# check_command() {
#     if ! command -v "$1" &> /dev/null; then
#         echo "error: $1 command not found. please install it and try again."
#         echo "on nixos live usb: nix-shell -p $2"
#         exit 1
#     fi
# }

# check_command parted parted
# check_command zpool zfs
# check_command mkfs.vfat dosfstools
# if $encryption; then
#     check_command cryptsetup cryptsetup
# fi

# check if disk is provided
if [ -z "$disk" ]; then
    echo "error: no disk specified"
    echo "available disks:"
    lsblk -dpno name,size,model,serial | grep -v "loop"
    echo ""
    echo "please specify a disk with -d or --disk"
    exit 1
fi

# check if disk exists
if ! [ -b "$disk" ]; then
    echo "error: disk $disk does not exist or is not a block device"
    exit 1
fi

# show disk details
echo "================= disk information ================="
lsblk -dpo name,size,model,serial "$disk"
echo "==================================================="

echo "warning: this will destroy all data on $disk"
echo "setup details:"
echo "  - hostname: $hostname"
echo "  - username: $username"
echo "  - efi size: ${efi_size}gb"
if $use_swap; then
    echo "  - swap size: ${swapsize}gb"
else
    echo "  - swap: disabled"
fi
echo "  - reserved space: ${reserve}gb"
if $encryption; then
    echo "  - encryption: enabled"
else
    echo "  - encryption: disabled"
fi
if $allow_discard; then
    echo "  - trim/discard: enabled (for ssd)"
else
    echo "  - trim/discard: disabled"
fi
echo ""
read -p "type yes to continue: " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "aborted."
    exit 1
fi

# get disk size and calculate partition sizes
echo "calculating disk layout..."
disk_size=$(blockdev --getsz "$disk")
sector_size=$(blockdev --getss "$disk")
disk_size_gb=$(awk "BEGIN {print $disk_size * $sector_size / 1024 / 1024 / 1024}")

# calculate partition boundaries
if $use_swap; then
    rpool_end_gb=$(awk "BEGIN {print $disk_size_gb - $swapsize - $reserve}")
    swap_end_gb=$(awk "BEGIN {print $disk_size_gb - $reserve}")
else
    rpool_end_gb=$(awk "BEGIN {print $disk_size_gb - $reserve}")
fi

echo "creating partition table..."
# create partitions with fixed sizes
parted --script --align=optimal "${disk}" mklabel gpt
parted --script --align=optimal "${disk}" mkpart efi fat32 1mib ${efi_size}gib
parted --script --align=optimal "${disk}" set 1 esp on

if $use_swap; then
    parted --script --align=optimal "${disk}" mkpart rpool ${efi_size}gib ${rpool_end_gb}gib
    parted --script --align=optimal "${disk}" mkpart swap ${rpool_end_gb}gib ${swap_end_gb}gib
else
    parted --script --align=optimal "${disk}" mkpart rpool ${efi_size}gib ${rpool_end_gb}gib
fi

# make sure kernel sees the new partition table
echo "updating partition table..."
partprobe "${disk}"
sleep 2

# get partition names
efi_part="${disk}1"
zfs_part="${disk}2"
if $use_swap; then
    swap_part="${disk}3"
fi

# format efi partition
echo "formatting efi partition..."
mkfs.vfat -f32 "$efi_part"

# set up encryption if requested
if $encryption; then
    echo "setting up luks encryption..."
    cryptsetup luksformat --type luks2 "$zfs_part"
    cryptsetup luksopen "$zfs_part" luks-rpool
    zfs_dev="/dev/mapper/luks-rpool"
else
    zfs_dev="$zfs_part"
fi

# format swap if requested
if $use_swap; then
    echo "formatting swap partition..."
    if $encryption; then
        cryptsetup luksformat --type luks1 "$swap_part"
        cryptsetup luksopen "$swap_part" luks-swap
        mkswap /dev/mapper/luks-swap
        swapon /dev/mapper/luks-swap
    else
        mkswap "$swap_part"
        swapon "$swap_part"
    fi
fi

# create zfs pool
echo "creating zfs pool with 'erase your darlings' layout..."
zpool create -f -o ashift=12 \
    -o compression=lz4 \
    -o acltype=posixacl \
    -o xattr=sa \
    -o relatime=on \
    -o normalization=formd \
    -o mountpoint=none \
    rpool "$zfs_dev"

# create datasets for erase-your-darlings setup
echo "creating datasets..."
# root dataset
zfs create -o mountpoint=none rpool/eyd
zfs create -o mountpoint=/ rpool/eyd/root

# create a blank snapshot for "erase your darlings"
echo "creating blank snapshot..."
zfs snapshot rpool/eyd/root@blank

# create persistent datasets
echo "creating persistent datasets..."
zfs create -o mountpoint=/nix rpool/eyd/nix
zfs create -o mountpoint=/home rpool/eyd/home
zfs create -o mountpoint=/persist rpool/eyd/per

# mount filesystems for nixos installation
echo "mounting filesystems..."
mkdir -p /mnt
mount -t zfs rpool/eyd/root /mnt
mkdir -p /mnt/{boot,nix,home,persist}
mount "$efi_part" /mnt/boot
mount -t zfs rpool/eyd/nix /mnt/nix
mount -t zfs rpool/eyd/home /mnt/home
mount -t zfs rpool/eyd/per /mnt/persist

# generate disk-by-id information
echo ""
echo "disk by-id paths (useful for configuration):"
for part in "${efi_part}" "${zfs_part}"; do
    if [ -e "$part" ]; then
        echo "$(readlink -f "$part") -> $(ls -l /dev/disk/by-id/* | grep "$(basename $(readlink -f "$part"))" | cut -d' ' -f9-)"
    fi
done

# create a basic configuration
echo ""
echo "creating example configuration files..."

# create configuration directory
mkdir -p /mnt/etc/nixos

# create minimal hardware-configuration.nix
cat > /mnt/etc/nixos/hardware-configuration.nix << eof
{ config, lib, pkgs, modulespath, ... }:

{
  imports = [ (modulespath + "/installer/scan/not-detected.nix") ];
  
  boot.supportedfilesystems = [ "zfs" ];
  boot.zfs.requestencryptioncredentials = $encryption;
  
  # use the systemd-boot efi boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.cantouchefivariables = true;
  
  # hardware components will be detected by nixos-generate-config
}
eof

# create minimal configuration.nix
cat > /mnt/etc/nixos/configuration.nix << eof
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];
  
  networking.hostname = "${hostname}";
  networking.hostid = "$(head -c 8 /etc/machine-id)"; # required for zfs
  
  
  # zfs settings
  services.zfs.autoscrub.enable = true;
  services.zfs.autosnapshot.enable = true;
  
  # basic system settings
  time.timezone = "utc";
  
  # define a user account
  users.users.${username} = {
    isnormaluser = true;
    extragroups = [ "wheel" "networkmanager" ];
    # set an initial password - change this after installation!
    initialpassword = "changeme";
  };
  
  # allow sudo without password for wheel group
  security.sudo.wheelneedspassword = false;
  
  # "erase your darlings" setup
  boot.initrd.postdevicecommands = lib.mkafter ''
    zfs rollback -r rpool/eyd/root@blank
  '';
  
  # basic system packages
  environment.systempackages = with pkgs; [
    wget vim git curl
    zfs
  ];
  
  # enable networkmanager
  networking.networkmanager.enable = true;
  
  system.stateversion = "23.11"; # do not change this value!
}
eof

# create a helpful boot-zfs.nix example
cat > /mnt/etc/nixos/boot-zfs.nix << eof
{ config, lib, pkgs, ... }:

{
  boot = {
    supportedfilesystems = [ "zfs" ];
    
    initrd = {
      systemd.enable = true;
      
eof

if $encryption; then
cat >> /mnt/etc/nixos/boot-zfs.nix << eof
      luks.devices = {
        "luks-rpool" = {
          device = "${zfs_part}";
          prelvm = true;
          allowdiscards = ${allow_discard};
        };
      };
      
eof
fi

cat >> /mnt/etc/nixos/boot-zfs.nix << eof
      # reset root filesystem
      systemd.services.reset = {
        description = "reset root filesystem";
        wantedby = ["initrd.target"];
        after = ["zfs-import.target"];
        before = ["sysroot.mount"];
        path = with pkgs; [zfs];
        unitconfig.defaultdependencies = "no";
        serviceconfig.type = "oneshot";
        script = "zfs rollback -r rpool/eyd/root@blank";
      };
    };
  };

eof

if $use_swap; then
cat >> /mnt/etc/nixos/boot-zfs.nix << eof
  swapdevices = [
    {
      device = "${swap_part}";
eof
    if $encryption; then
cat >> /mnt/etc/nixos/boot-zfs.nix << eof
      randomencryption = {
        enable = true;
        allowdiscards = ${allow_discard};
      };
eof
    fi
cat >> /mnt/etc/nixos/boot-zfs.nix << eof
    }
  ];

eof
fi

cat >> /mnt/etc/nixos/boot-zfs.nix << eof
  services.zfs = {
    autoscrub.enable = true;
    autosnapshot.enable = true;
  };
}
eof

# create a persistent directories list
cat > /mnt/persist/directories.txt << eof
# this file lists directories that should be made persistent
# create symlinks or bind mounts from /persist to these locations

# example system directories
/etc/ssh
/etc/networkmanager/system-connections

# example user-specific directories
/home/${username}/.ssh
/home/${username}/.gnupg
/home/${username}/.config
eof

# create a setup instructions file
cat > /mnt/setup-instructions.txt << eof
zfs nixos setup instructions
===========================

your zfs "erase your darlings" system is prepared with the following layout:

- rpool/eyd/root  -> /        (ephemeral root that resets on reboot)
- rpool/eyd/nix   -> /nix     (persistent nix store)
- rpool/eyd/home  -> /home    (persistent home directories)
- rpool/eyd/per   -> /persist (persistent system data)

to complete installation:

1. generate hardware configuration:
   # nixos-generate-config --root /mnt

2. edit configuration files:
   # nano /mnt/etc/nixos/configuration.nix

3. install nixos:
   # nixos-install

4. set your root password when prompted

5. after reboot, don't forget to:
   - change your user password
   - set up persistence for important directories (see /persist/directories.txt)

for persistence, you can create symlinks or bind mounts:
  mkdir -p /persist/etc/ssh
  ln -s /persist/etc/ssh /etc/ssh

or add this to your configuration.nix:
  filesystems."/etc/ssh".fstype = "none";
  filesystems."/etc/ssh".device = "/persist/etc/ssh";
  filesystems."/etc/ssh".options = [ "bind" ];
eof

echo ""
echo "==================== success ===================="
echo "zfs setup complete! the system is ready for nixos installation."
echo ""
echo "your zfs layout:"
zfs list
echo ""
echo "next steps:"
echo "1. run: nixos-generate-config --root /mnt"
echo "2. edit configurations in /mnt/etc/nixos/"
echo "3. install nixos: nixos-install"
echo ""
echo "see /mnt/setup-instructions.txt for more details"
echo "================================================="
