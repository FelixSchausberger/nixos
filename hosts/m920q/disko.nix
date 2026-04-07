# m920q disk configuration
#
# Disk layout:
#   - main (256GB SSD): ZFS rpool with impermanence via shared template
#   - data (2TB SATA SSD): dpool at /per/mnt/data — add when drive is installed
import ../disko-zfs-template.nix {
  # EUI-64 identifier is stable and udev-independent; SAMSUNG by-id names can
  # vary between udev versions and were unavailable when disko ran on the ISO
  device = "/dev/disk/by-id/nvme-eui.002538c381b0aeb4";
  swapSize = "8G";
  poolName = "rpool";
}
