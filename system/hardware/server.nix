# Hardware configuration for headless server hosts.
# Includes audio and Bluetooth for local streaming use cases.
# Excludes desktop graphics stack and laptop-specific modules.
{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./zfs.nix
  ];

  boot.kernelParams = [
    "elevator=mq-deadline" # ZFS workload optimization
  ];

  hardware = {
    enableAllFirmware = true;
    # Intel UHD 630 iGPU: minimal init for headless; graphics stack enabled
    # via niri-gui specialisation when local display is needed
    graphics.enable = false;
    cpu.intel.updateMicrocode = true;
  };
}
