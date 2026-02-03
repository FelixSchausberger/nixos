{
  config,
  inputs,
  ...
}: let
  hostName = "portable";
  hostInfo = inputs.self.lib.hostData.${hostName};
in {
  imports = [
    ./disko.nix
    ../shared-tui.nix
    ../boot-zfs.nix # Portable needs ZFS support for recovery
    ../../modules/system/recovery-tools.nix
    ../../modules/system/specialisations.nix
    ../../modules/system/performance-profiles.nix
  ];

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    wm = hostInfo.wms;
    # user and system use defaults from lib/defaults.nix

    # Portable-specific specialisations for recovery scenarios
    specialisations = {
      # Enhanced recovery mode with additional tools
      recovery = {
        wm = null; # Inherit from parent (TUI-only)
        profile = "default";
        extraConfig = {pkgs, ...}: {
          # Additional recovery and diagnostic tools
          environment.systemPackages = with pkgs; [
            testdisk # Data recovery
            photorec # Photo recovery
            ddrescue # Disk rescue
            gpart # Partition recovery
            hdparm # Hard disk parameters
            smartmontools # SMART monitoring
            ntfs3g # NTFS support
            exfatprogs # exFAT support
          ];
        };
      };
    };
  };

  # Hardware compatibility enhancements for portable use
  boot = {
    kernelParams = [
      "nohibernate"
      # Add parameters for better hardware compatibility
      "i915.force_probe=*" # Force Intel GPU drivers
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Better NVIDIA compatibility
      "usbcore.autosuspend=-1" # Prevent USB devices from auto-suspending
    ];

    # Extra kernel modules for better hardware compatibility
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback # For virtual webcam support
    ];

    # Load additional kernel modules for better hardware compatibility
    kernelModules = [
      "v4l2loopback"
      # Common hardware support
      "thunderbolt"
      "uvcvideo"
      "hid_multitouch"
    ];
  };

  # File systems - add neededForBoot for ephemeral storage
  fileSystems."/home".neededForBoot = true;

  # Essential hardware support for portable use
  hardware = {
    # Better GPU compatibility
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  # XDG portals - minimal configuration for TUI-only system
  # xdg.portal = {
  #   enable = true;
  #   config.common.default = "*"; # Use any available portal backend
  # };
}
