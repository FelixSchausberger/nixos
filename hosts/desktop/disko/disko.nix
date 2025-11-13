# Disko configuration for desktop host
#
# Simple ext4-based system with:
# - EFI System Partition (512MB) at /boot
# - Optional swap partition (configurable size)
# - ext4 root partition
#
# Usage:
#   sudo nix run 'github:nix-community/disko#disko-install' -- \
#     --flake '.#desktop' \
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

            # Swap partition
            # Adjust size as needed for your use case
            swap = {
              priority = 2;
              size = "16G";
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
