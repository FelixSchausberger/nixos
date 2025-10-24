{
  config,
  lib,
  pkgs,
  ...
}: let
  # Use ZFS-compatible kernel
  # Note: Using linuxPackages_latest can cause build failures with newer kernels
  # Stick to LTS kernels for stability
  kernelPackages =
    if config.boot.zfs.forceLatestStableKernel
    # Use the latest stable LTS kernel that's known to work with ZFS
    # 6.6.x is a stable LTS release with good ZFS support
    then pkgs.linuxPackages_6_6
    else pkgs.linuxPackages;
in {
  options.boot.zfs = {
    forceLatestStableKernel = lib.mkOption {
      type = lib.types.bool;
      default = true; # Default to true for ZFS compatibility across all hosts
      description = "Whether to force the latest stable kernel for ZFS compatibility";
    };
  };

  config = {
    boot = {
      loader = {
        systemd-boot = {
          enable = true;
          editor = true; # Allow recovery by passing init=/bin/sh
          consoleMode = "max";
          configurationLimit = 20;

          extraEntries = {
            "nixos-emergency.conf" = ''
              title NixOS Emergency Mode
              linux /nixos/current/kernel
              initrd /nixos/current/initrd
              options systemd.unit=emergency.target
            '';
            "nixos-rescue.conf" = ''
              title NixOS Rescue Mode
              linux /nixos/current/kernel
              initrd /nixos/current/initrd
              options systemd.unit=rescue.target
            '';
          };
        };

        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot"; # Adjust if your ESP is mounted elsewhere
        };

        timeout = 0;
      };

      kernelPackages = lib.mkDefault kernelPackages;

      # Ensure ZFS kernel module matches userspace tools
      zfs = {
        package = pkgs.zfs.override {
          # Use the same kernel sources as our kernelPackages
          inherit (kernelPackages) kernel;
        };
        extraPools = ["rpool"];
      };

      supportedFilesystems = [
        "ntfs"
        "zfs"
      ];

      initrd = {
        systemd.enable = true;

        systemd.services = {
          reset-root = {
            description = "Reset root filesystem to blank snapshot";
            wantedBy = ["initrd.target"];
            after = ["zfs-import.target"];
            before = ["sysroot.mount"];
            path = [pkgs.zfs];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = "zfs rollback -r rpool/eyd/root@blank";
          };

          enable-autotrim = {
            description = "Enable ZFS autotrim";
            wantedBy = ["initrd.target"];
            after = ["zfs-import.target"];
            before = ["sysroot.mount"];
            path = [pkgs.zfs];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = "zpool set autotrim=on rpool";
          };
        };
      };

      kernelParams = [
        "nohibernate"
        "console=tty1"
        "systemd.show_status=true"
      ];

      plymouth = {
        enable = false;
      };
    };

    services.zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;

      zed = {
        settings = {
          ZED_DEBUG_LOG = "/var/log/zed.debug";
          ZED_IGNORE_EID = "1";
          ZED_IGNORED_HISTORY = "1";
        };
      };
    };

    systemd.services = {
      zfs-zed = {
        serviceConfig = {
          Restart = "always";
          RestartSec = "5s";
          StartLimitIntervalSec = "0";
        };
      };

      # Ensure proper ordering with ZFS
      system-systemd-swap = {
        after = [
          "zfs.target"
          "zfs-mount.service"
        ];
        requires = [
          "zfs.target"
          "zfs-mount.service"
        ];
      };

      nsncd = {
        after = [
          "zfs.target"
          "systemd-swap.target"
        ];
        requires = [
          "zfs.target"
          "systemd-swap.target"
        ];
      };
    };
  };
}
