# Surface Pro (2017) hardware baseline. Disk layout (fileSystems) comes from
# ../disko.nix via the disko module; this file carries only what disko cannot
# know: kernel modules, parameters, power and CPU specifics.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "sd_mod"];
      kernelModules = [];
      supportedFilesystems = ["zfs"];
    };
    kernelModules = ["kvm-intel"];
    kernelParams = ["i915.force_probe=5916"];
    extraModulePackages = [];
  };

  # Mirrors ../disko.nix (rpool/eyd datasets, impermanence with @blank rollback).
  fileSystems = {
    "/" = {
      device = "rpool/eyd/root";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/nix" = {
      device = "rpool/eyd/nix";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/per" = {
      device = "rpool/eyd/per";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/home" = {
      device = "rpool/eyd/home";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/boot" = {
      device = lib.mkDefault "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
      neededForBoot = true;
    };
  };

  # The disko swap partition (8G, randomEncryption) exists for the install
  # phase only; the running system uses zram (see desktop for the rationale).
  swapDevices = [];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking = {
    useDHCP = lib.mkDefault true;
    # interfaces.wlp1s0.useDHCP = lib.mkDefault true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkOverride 1500 "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
