# VMware VM hardware configuration for HP ProBook 465 G11
# AMD Ryzen 7 7735U with Radeon Graphics
#
# This configuration is for a VMware Workstation Pro 17.6 VM
# Guest will have access to host's AMD Ryzen CPU and Radeon iGPU
{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Boot configuration for EFI
  boot = {
    # Kernel modules for initrd
    initrd = {
      availableKernelModules = [
        "ata_piix" # Legacy ATA controller support
        "uhci_hcd" # USB 1.1 controller
        "ehci_pci" # USB 2.0 controller
        "ahci" # SATA controller
        "sd_mod" # SCSI disk support
        "sr_mod" # SCSI CD-ROM support
        "vmw_pvscsi" # VMware paravirtual SCSI
        "vmxnet3" # VMware paravirtual network
      ];
      # Load AMD GPU driver early for graphical boot
      kernelModules = ["amdgpu"];
    };

    # Kernel modules for running system
    kernelModules = [
      "amdgpu" # AMD GPU driver
      "kvm-amd" # AMD KVM virtualization (for nested virt)
    ];

    # VMware-specific kernel parameters
    kernelParams = [
      "amdgpu.dc=1" # Enable AMD Display Core for better compatibility
    ];

    extraModulePackages = [];

    # Bootloader configuration
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = lib.mkDefault 3; # Quick boot timeout for VM
    };
  };

  # File systems - to be configured after VM installation
  # These are placeholders and should be updated after running nixos-generate-config
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      options = ["defaults" "noatime"]; # noatime for better VM performance
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = ["fmask=0022" "dmask=0022"];
    };
  };

  # Use zramSwap instead of disk swap for better VM performance
  # This is configured system-wide in modules/system/core/swap.nix
  swapDevices = [];

  # Hardware configuration
  hardware = {
    # Enable graphics with 32-bit support
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    # AMD CPU microcode updates
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # Enable all firmware for better hardware support
    enableAllFirmware = true;
  };

  # VMware-specific services
  virtualisation.vmware.guest = {
    enable = true;
    headless = false; # We want GUI support
  };

  # Network configuration
  networking = {
    useDHCP = lib.mkDefault true;
    # VMware typically provides a single network interface
    # DHCP will auto-configure it
  };

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # VMware-specific system packages
  environment.systemPackages = with pkgs; [
    open-vm-tools # VMware guest utilities
  ];

  # Enable VMware shared folders (optional)
  # Uncomment if you want to share folders between host Windows and guest NixOS
  # fileSystems."/mnt/hgfs" = {
  #   device = ".host:/";
  #   fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";
  #   options = [
  #     "umask=22"
  #     "uid=1000"
  #     "gid=100"
  #     "allow_other"
  #     "auto_unmount"
  #     "defaults"
  #   ];
  # };
}
