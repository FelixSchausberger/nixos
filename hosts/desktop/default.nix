{
  imports = [
    ./boot-zfs.nix
    ../../system/programs/shared
    ./hardware-configuration.nix
  ];

  # Enable 32-bit support for Direct Rendering Infrastructure (DRI)
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    keyboard.qmk.enable = true;
  };
}
