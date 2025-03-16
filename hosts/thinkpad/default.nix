{
  imports = [
    ./boot-zfs.nix
    ./hardware-configuration.nix
  ];

  # Enable 32-bit support for Direct Rendering Infrastructure (DRI)
  # hardware = {
  #   graphics = {
  #     enable32Bit = true;
  #   };

  #   keyboard.qmk.enable = true;
  # };
}
