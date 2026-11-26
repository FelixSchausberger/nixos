# m920q disk configuration
#
# Disk layout:
#   - main (256GB NVMe): ZFS rpool with impermanence
#   - data (2TB SATA WD Green): dpool at /per/mnt/data
#   - backup (4TB Micron X10 Pro): bpool at /per/mnt/backup
let
  # All three pools start from the same property set; the datasets that need
  # different snapshot behaviour override "com.sun:auto-snapshot" individually.
  poolRootFsOptions = {
    compression = "zstd";
    acltype = "posixacl";
    xattr = "sa";
    atime = "off";
    "com.sun:auto-snapshot" = "false";
  };
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-eui.002538c381b0aeb4";
        content = {
          type = "gpt";
          partitions = {
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
            swap = {
              priority = 2;
              size = "8G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
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
      data = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WD_Green_2.5_2TB_24254H4A0P12";
        content = {
          type = "gpt";
          partitions.data = {
            size = "100%";
            type = "BF00";
            content = {
              type = "zfs";
              pool = "dpool";
            };
          };
        };
      };
      backup = {
        type = "disk";
        device = "/dev/disk/by-id/usb-Micron_CT4000X10PROSSD9_2419E8CE9042-0:0";
        content = {
          type = "gpt";
          partitions.backup = {
            size = "100%";
            type = "BF00";
            content = {
              type = "zfs";
              pool = "bpool";
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        rootFsOptions = poolRootFsOptions;
        datasets = {
          "eyd" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };
          "eyd/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "/";
              "com.sun:auto-snapshot" = "false";
            };
            postCreateHook = "zfs snapshot rpool/eyd/root@blank";
          };
          "eyd/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "/nix";
              atime = "off";
              "com.sun:auto-snapshot" = "false";
            };
          };
          "eyd/per" = {
            type = "zfs_fs";
            mountpoint = "/per";
            options = {
              mountpoint = "/per";
              # sanoid owns this tree; zfstools would run a second snapshot
              # engine over it and pin duplicate history.
              "com.sun:auto-snapshot" = "false";
            };
          };
          "eyd/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "/home";
              # sanoid owns the home snapshot chain: it can prune its own
              # autosnap_* names, while zfstools' zfs-auto-snap_* names are
              # invisible to sanoid and would accrete on the replica forever.
              "com.sun:auto-snapshot" = "false";
            };
          };
          "eyd/per/repos" = {
            type = "zfs_fs";
            mountpoint = "/per/repos";
            options = {
              mountpoint = "/per/repos";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
      dpool = {
        type = "zpool";
        rootFsOptions = poolRootFsOptions;
        datasets = {
          data = {
            type = "zfs_fs";
            mountpoint = "/per/mnt/data";
            options = {
              mountpoint = "/per/mnt/data";
              "com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
      bpool = {
        type = "zpool";
        rootFsOptions = poolRootFsOptions;
        datasets = {
          backup = {
            type = "zfs_fs";
            mountpoint = "/per/mnt/backup";
            options = {
              mountpoint = "/per/mnt/backup";
              "com.sun:auto-snapshot" = "false";
            };
          };
          # The syncoid receiver for dpool/data. Declared so fresh installs
          # ship the same layout the runtime replication creates; it is a
          # replica sink, not user-facing storage (do not curate files here).
          "backup/data" = {
            type = "zfs_fs";
            mountpoint = "/per/mnt/backup/data";
            options = {
              mountpoint = "/per/mnt/backup/data";
            };
          };
          # Replica sink for rpool/eyd/home.
          "backup/home" = {
            type = "zfs_fs";
            mountpoint = "/per/mnt/backup/home";
            options = {
              mountpoint = "/per/mnt/backup/home";
            };
          };
          # Replica sink for rpool/eyd/per. Its only content is what syncoid
          # receives, and sanoid on the host prunes the target-only snapshots
          # down to one per month.
          "backup/per" = {
            type = "zfs_fs";
            mountpoint = "/per/mnt/backup/per";
            options = {
              mountpoint = "/per/mnt/backup/per";
            };
          };
          # Cold store for the pre-NixOS manual backups and logical dumps.
          # 1M records concentrate sequential reads; the archive is written
          # once and read rarely.
          "backup/archive" = {
            type = "zfs_fs";
            mountpoint = "/per/mnt/backup/archive";
            options = {
              mountpoint = "/per/mnt/backup/archive";
              recordsize = "1M";
            };
          };
        };
      };
    };
  };
}
