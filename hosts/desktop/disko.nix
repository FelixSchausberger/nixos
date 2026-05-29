# Desktop ZFS disko configuration using shared template
# 16GB swap for desktop workstation
import ../disko-zfs-template.nix {
  device = "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b444a4197bc43";
  swapSize = "16G";
  poolName = "rpool";
}
