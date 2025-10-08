{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./graphics.nix
    ./zfs.nix
    ../../modules/system/hardware/amd-gpu.nix
  ];

  # I/O scheduler optimization for ZFS
  boot.kernelParams = [
    "elevator=mq-deadline" # Better for ZFS workloads
  ];

  hardware = {
    enableAllFirmware = true;
    # Better power management
    acpilight.enable = true;
  };
}
