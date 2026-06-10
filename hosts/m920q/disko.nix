# m920q disk configuration
#
# Disk layout:
#   - main (256GB NVMe): ZFS rpool with impermanence
#   - data (2TB SATA WD Green): dpool at /per/mnt/data
#   - backup (1TB SanDisk Extreme): bpool at /per/mnt/backup
{
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
        device = "/dev/disk/by-id/ata-SanDisk_Extreme_Portable_SSD_20521E804590";
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
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
        };
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
              "com.sun:auto-snapshot" = "true";
            };
          };
          "eyd/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "/home";
              "com.sun:auto-snapshot" = "true";
            };
          };
          "eyd/per/repos" = {
            type = "zfs_fs";
            mountpoint = "/per/repos";
            options = {
              mountpoint = "/per/repos";
              "com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
      dpool = {
        type = "zpool";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
        };
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
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
        };
        datasets = {
          backup = {
            type = "zfs_fs";
            mountpoint = "/per/mnt/backup";
            options = {
              mountpoint = "/per/mnt/backup";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
    };
  };
}
