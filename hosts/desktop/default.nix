{
  imports = [
    ./boot-zfs.nix
    ../../modules/system
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
