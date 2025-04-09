{
  imports = [
    ./boot-zfs.nix
    ../../system/programs/private
    ../../system/programs/shared
    ./hardware-configuration.nix
  ];

  # Enable 32-bit support for Direct Rendering Infrastructure (DRI)
  hardware = {
    graphics = {
      enable32Bit = true;
    };

    # Better GPU compatibility
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    keyboard.qmk.enable = true;
  };
}
