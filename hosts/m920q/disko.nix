# m920q disk configuration
#
# Disk layout:
#   - main (256GB SSD): ZFS rpool with impermanence via shared template
#   - data (2TB SATA SSD): dpool at /per/mnt/data — add when drive is installed
import ../disko-zfs-template.nix {
  device = "/dev/disk/by-id/nvme-SAMSUNG_MZVPW256HEGL-000H1_S34ENBOK311982";
  swapSize = "8G";
  poolName = "rpool";
}
