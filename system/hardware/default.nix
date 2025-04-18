{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./graphics.nix
  ];

  hardware = {
    enableAllFirmware = true;
    # Better power management
    acpilight.enable = true;
  };
}
