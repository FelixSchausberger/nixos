{config, ...}: {
  imports = [../boot-zfs.nix];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      timeout = 5; # A bit longer timeout for the portable system
    };

    # Hardware compatibility enhancements for portable use
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
      broadcom_sta # Common WiFi driver
      rtl8821au # Common WiFi driver
      rtl8821cu # Common WiFi driver
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

  # No LUKS encryption config here yet - add it if you want your portable system encrypted
  # Uncomment if adding encryption
  # boot.initrd.luks.devices = {
  #   "luks-portable" = {
  #     device = "/dev/disk/by-id/YOUR_DISK_ID-part2";
  #     preLVM = true;
  #   };
  # };

  # No swap configuration here yet - add it if needed
  # swapDevices = [ ... ];
}
