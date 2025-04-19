{
  imports = [
    ./boot-zfs.nix
    ./hardware-configuration.nix
    ../../modules/system
    ../../modules/system/work
    ../../system/nix/work/substituters.nix
  ];

  # Enable 32-bit support for Direct Rendering Infrastructure (DRI)
  # hardware = {
  #   graphics = {
  #     enable32Bit = true;
  #   };

  #   keyboard.qmk.enable = true;
  # };
}
