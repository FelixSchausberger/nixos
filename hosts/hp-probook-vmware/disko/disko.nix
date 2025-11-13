# Disko configuration for hp-probook-vmware host
#
# VMware VM with simple ext4-based system:
# - EFI System Partition (512MB) at /boot
# - No disk swap (using zramSwap instead)
# - ext4 root partition with noatime for VM performance
#
# Usage:
#   sudo nix run 'github:nix-community/disko#disko-install' -- \
#     --flake '.#hp-probook-vmware' \
#     --disk main /dev/sda
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

            # Root partition (uses remaining space)
            # No swap partition - using zramSwap for better VM performance
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                  "noatime" # Better performance in VMs
                ];
              };
            };
          };
        };
      };
    };
  };
}
