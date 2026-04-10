# Portable ZFS disko configuration using shared template
# No swap for portable use
import ../disko-zfs-template.nix {
  device = "/dev/disk/by-id/changeme";
  swapSize = null; # No swap for portable
  poolName = "rpool";
}
