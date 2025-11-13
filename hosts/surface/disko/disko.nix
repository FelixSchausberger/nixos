# Disko configuration for surface host
#
# Simple ext4-based system with:
# - EFI System Partition (512MB) at /boot
# - Optional swap partition (smaller for mobile device)
# - ext4 root partition
#
# Usage:
#   sudo nix run 'github:nix-community/disko#disko-install' -- \
#     --flake '.#surface' \
#     --disk main /dev/nvme0n1
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/changeme";
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition
            ESP = {
              priority = 1;
              name = "boot";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0077"
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };

            # Swap partition (8GB for mobile device)
            swap = {
              priority = 2;
              size = "8G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };

            # Root partition (uses remaining space)
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
