{
  config,
  lib,
  pkgs,
  ...
}: let
  # Select the latest zfs-compatible kernel
  zfsCompatibleKernelPackages =
    lib.filterAttrs (
      name: kernelPackages:
        (builtins.match "linux_[0-9]+_[0-9]+" name)
        != null
        && (builtins.tryEval kernelPackages).success
        && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
    )
    pkgs.linuxKernel.packages;
  latestKernelPackage = lib.last (
    lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
      builtins.attrValues zfsCompatibleKernelPackages
    )
  );
in {
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        editor = true; # Set to true allows gaining root access by passing init=/bin/sh as a kernel parameter
        consoleMode = "max";
        configurationLimit = 20;

        # Recovery shell
        extraEntries = {
          "nixos-recovery.conf" = ''
            title NixOS Recovery
            linux /nixos/current/kernel
            initrd /nixos/current/initrd
            options init=/bin/sh
          '';
        };
      };

      grub.device = "/dev/nvme0n1";

      efi.canTouchEfiVariables = true;
      timeout = 0;
    };

    supportedFilesystems = ["ntfs" "zfs"];
    initrd = {
      systemd.enable = true;

      # systemd in initrd requires a service instead of a command
      systemd.services.reset = {
        description = "reset root filesystem";
        wantedBy = ["initrd.target"];
        after = ["zfs-import.target"];
        before = ["sysroot.mount"];
        path = with pkgs; [zfs];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = "zfs rollback -r rpool/eyd/root@blank";
      };

      systemd.services.zfs-autotrim = {
        description = "Enable ZFS autotrim";
        wantedBy = ["initrd.target"];
        after = ["zfs-import.target"];
        before = ["sysroot.mount"];
        path = with pkgs; [zfs];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = "zpool set autotrim=on rpool";
      };
    };

    kernelPackages = latestKernelPackage;
    kernelParams = ["nohibernate"]; # "quiet" "udev.log_level=3"];
  };

  systemd.services.system-systemd-swap = {
    after = ["zfs.target" "zfs-mount.service"];
    requires = ["zfs.target" "zfs-mount.service"];
  };

  systemd.services.nsncd = {
    after = ["zfs.target" "systemd-swap.target"];
    requires = ["zfs.target" "systemd-swap.target"];
  };

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };
}
