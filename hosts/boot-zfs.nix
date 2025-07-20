{
  config,
  lib,
  pkgs,
  ...
}: let
  # Get the latest stable ZFS-compatible kernel
  latestStableKernel = let
    kernels = lib.filterAttrs (name: _: lib.hasPrefix "linux_" name) pkgs.linuxKernel.packages;
    stableKernels = lib.filterAttrs (_: pkg: !(pkg.kernel.features ? preemptrt)) kernels;
  in
    lib.last (lib.sort (a: b: lib.versionOlder a.kernel.version b.kernel.version)
      (lib.attrValues stableKernels));

  # Use either the latest stable kernel or the default one
  kernelPackages =
    if config.boot.zfs.forceLatestStableKernel
    then latestStableKernel
    else pkgs.linuxPackages;
in {
  options.boot.zfs = {
    forceLatestStableKernel = lib.mkOption {
      type = lib.types.bool;
      default = false;
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
          kernel = kernelPackages.kernel;
        };
        extraPools = ["rpool"];
      };

      supportedFilesystems = ["ntfs" "zfs"];

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
        after = ["zfs.target" "zfs-mount.service"];
        requires = ["zfs.target" "zfs-mount.service"];
      };

      nsncd = {
        after = ["zfs.target" "systemd-swap.target"];
        requires = ["zfs.target" "systemd-swap.target"];
      };
    };
  };
}
