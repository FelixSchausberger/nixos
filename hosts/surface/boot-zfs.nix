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
        editor = false; # Set to true allows gaining root access by passing init=/bin/sh as a kernel parameter
        consoleMode = "max";
        configurationLimit = 10;
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
    kernelParams = ["nohibernate" "quiet" "udev.log_level=3"];
  };

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };
}
