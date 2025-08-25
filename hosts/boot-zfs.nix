{
  config,
  lib,
  pkgs,
  ...
}: let
  # Use ZFS-compatible kernel
  kernelPackages =
    if config.boot.zfs.forceLatestStableKernel
    # https://discourse.nixos.org/t/zfs-latestcompatiblelinuxpackages-is-deprecated/52540
    then pkgs.linuxPackages_6_6 # Use stable LTS kernel compatible with ZFS
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
            "nixos-recovery.conf" = ''
              title NixOS Recovery
              linux /nixos/current/kernel
              initrd /nixos/current/initrd
              options init=/bin/sh
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

      kernelParams = ["nohibernate"];

      # Plymouth boot splash screen disabled due to known issue with ZFS/LUKS encryption
      # where it hides the password prompt causing apparent boot loop
      # See: https://github.com/NixOS/nixpkgs/issues/44965
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
