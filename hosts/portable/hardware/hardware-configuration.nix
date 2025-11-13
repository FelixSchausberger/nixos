# Hardware configuration for portable recovery/workstation system
# This configuration is designed to work with various hardware and portable systems
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
    # ZFS filesystems
    supportedFilesystems = ["zfs"];
    zfs = {
      devNodes = "/dev/disk/by-id";
      forceImportRoot = false;
    };

    initrd = {
      availableKernelModules = [
        # SATA/AHCI controllers
        "ahci"
        "ata_piix"
        # NVMe support
        "nvme"
        # USB controllers
        "xhci_pci"
        "ehci_pci"
        "ohci_pci"
        "uhci_hcd"
        # USB storage
        "usb_storage"
        "uas"
        # SCSI
        "sd_mod"
        "sr_mod"
        # Virtio for VM compatibility
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
        "virtio_net"
        # Other common storage
        "mmc_block"
      ];

      kernelModules = [
        # Graphics modules for various hardware
        "i915" # Intel
        "amdgpu" # AMD
        "radeon" # Older AMD
        # HID devices
        "hid_generic"
        "hid_multitouch"
        "usbhid"
      ];
    };

    # Kernel modules to load
    kernelModules = [
      "kvm-intel"
      "kvm-amd"
    ];

    extraModulePackages = [];
  };

  # ZFS filesystem configuration - these paths will be used by the image builder
  fileSystems = {
    "/" = {
      device = "rpool/eyd/root";
      fsType = "zfs";
      options = ["zfsutil"];
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };

    "/nix" = {
      device = "rpool/eyd/nix";
      fsType = "zfs";
      options = ["zfsutil"];
      neededForBoot = true;
    };

    "/home" = {
      device = "rpool/eyd/home";
      fsType = "zfs";
      options = ["zfsutil"];
    };

    "/per" = {
      device = "rpool/eyd/per";
      fsType = "zfs";
      options = ["zfsutil"];
      neededForBoot = true;
    };
  };

  # Dedicated encrypted swap partition (best practice for performance)
  # TODO: Replace with actual PARTUUID when hardware is available
  # swapDevices = [
  #   {
  #     device = "/dev/disk/by-partuuid/swap-uuid-here";
  #     randomEncryption = {
  #       enable = true;
  #       allowDiscards = true;
  #     };
  #   }
  # ];
  swapDevices = [];

  # Network configuration - compatible with various interfaces
  networking = {
    useDHCP = lib.mkDefault true;
    # Enable all common interface types
    interfaces = {
      # Ethernet interfaces (common names)
      eth0.useDHCP = lib.mkDefault true;
      enp0s3.useDHCP = lib.mkDefault true;
      enp1s0.useDHCP = lib.mkDefault true;
      # Wireless interfaces
      wlan0.useDHCP = lib.mkDefault true;
      wlp2s0.useDHCP = lib.mkDefault true;
    };
  };

  # Platform configuration
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Hardware optimizations for portable use
  hardware = {
    # Enable microcode updates for Intel and AMD
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # Enable firmware for better hardware compatibility
    enableRedistributableFirmware = lib.mkDefault true;
    enableAllFirmware = lib.mkDefault true;
  };

  # Power management for portable use
  powerManagement = {
    enable = lib.mkDefault true;
    cpuFreqGovernor = lib.mkDefault "powersave";
  };

  # Services optimized for portable/recovery use
  services = {
    # Thermald for thermal management (Intel)
    thermald.enable = lib.mkDefault true;

    # TLP for laptop power management
    tlp = {
      enable = lib.mkDefault true;
      settings = {
        # Battery conservation settings
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;
        # CPU settings for balanced performance/battery life
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    };

    # Auto-suspend USB devices to save power
    upower.enable = lib.mkDefault true;
  };
}
