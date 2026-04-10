# Shared ZFS disko configuration template with impermanence
#
# Parameterized template for ZFS-based systems used by:
# - desktop (16GB swap, /dev/disk/by-id/changeme)
# - portable (no swap, /dev/disk/by-id/changeme)
# - hp-probook-vmware (8GB swap, /dev/sda)
#
# Defines disk layout with:
# - EFI System Partition (512MB) at /boot
# - Optional swap partition (encrypted)
# - ZFS pool with impermanence (ephemeral root)
#
# Usage:
#   import ../disko-zfs-template.nix {
#     device = "/dev/sda";
#     swapSize = "8G";  # or null for no swap
#     poolName = "rpool";
#   }
{
  device ? "/dev/disk/by-id/changeme",
  swapSize ? null,
  poolName ? "rpool",
}: let
  # Build partition list conditionally based on swapSize
  partitions =
    {
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
    }
    // (
      if swapSize != null
      then {
        # Swap partition (encrypted)
        swap = {
          priority = 2;
          size = swapSize;
          content = {
            type = "swap";
            randomEncryption = true;
          };
        };
      }
      else {}
    )
    // {
      # ZFS root partition (uses remaining space)
      zfs = {
        size = "100%";
        content = {
          type = "zfs";
          pool = poolName;
        };
      };
    };
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          inherit partitions;
        };
      };
    };

    zpool = {
      ${poolName} = {
        type = "zpool";
        # ZFS pool options matching existing boot-zfs.nix configuration
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
        };

        datasets = {
          # Parent dataset (not mounted)
          "eyd" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };

          # Ephemeral root (blank snapshot for impermanence)
          # Rolled back to @blank on every boot via boot-zfs.nix
          "eyd/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "/";
              "com.sun:auto-snapshot" = "false";
            };
            postCreateHook = ''
              zfs snapshot ${poolName}/eyd/root@blank
            '';
          };

          # Nix store (persistent, no snapshots)
          "eyd/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "/nix";
              atime = "off";
              "com.sun:auto-snapshot" = "false";
            };
          };

          # Persistence dataset (snapshots enabled)
          "eyd/per" = {
            type = "zfs_fs";
            mountpoint = "/per";
            options = {
              mountpoint = "/per";
              "com.sun:auto-snapshot" = "true";
            };
          };

          # Home directory (snapshots enabled)
          "eyd/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "/home";
              "com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
    };
  };
}
