# Desktop ZFS disko configuration using shared template
# 16GB swap for desktop workstation
import ../disko-zfs-template.nix {
  device = "/dev/disk/by-id/changeme";
  swapSize = "16G";
  poolName = "rpool";
}
