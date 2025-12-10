# Disko configuration for hp-probook-vmware host with ZFS and impermanence
#
# VMware VM with ZFS-based system (matching physical hosts):
# - EFI System Partition (512MB) at /boot
# - Optional swap partition (8GB for VM)
# - ZFS pool with impermanence (ephemeral root)
#
# Usage with nixos-anywhere:
#   nix run github:nix-community/nixos-anywhere -- \
#     --flake .#hp-probook-vmware \
#     root@<vm-ip>
#
# Note: Disk device defaults to /dev/sda (common in VMs)
_: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
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

            # Swap partition (8GB for VM)
            swap = {
              priority = 2;
              size = "8G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };

            # ZFS root partition (uses remaining space)
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
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
              zfs snapshot rpool/eyd/root@blank
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
