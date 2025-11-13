{
  config,
  inputs,
  ...
}: let
  hostName = "portable";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports = [
    ../shared-tui.nix
    ../boot-zfs.nix # Portable needs ZFS support for recovery
    ../../modules/system/recovery-tools.nix
  ];

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    wm = hostInfo.wms;
    # user and system use defaults from lib/defaults.nix
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
