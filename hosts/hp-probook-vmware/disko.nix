# HP-ProBook-VMware ZFS disko configuration using shared template
# 8GB swap for VM, /dev/sda device (VMware default)
import ../disko-zfs-template.nix {
  device = "/dev/sda";
  swapSize = "8G";
  poolName = "rpool";
}
