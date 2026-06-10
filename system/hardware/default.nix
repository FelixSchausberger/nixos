{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./graphics.nix
    ./zfs.nix
    ../../modules/system/hardware/amd-gpu.nix
  ];

  hardware = {
    enableAllFirmware = true;
    # Better power management
    acpilight.enable = true;
  };
}
