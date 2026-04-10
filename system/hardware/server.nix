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
    cpu.intel.updateMicrocode = true;
  };
}
