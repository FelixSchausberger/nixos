{
  # Import the shared boot-zfs.nix configuration
  imports = [../boot-zfs.nix];

  # Surface-specific boot configuration overrides
  boot.loader.grub.device = "/dev/nvme0n1"; # You can override this if needed

  # Add any surface-specific configurations here
  # For example, if surface gets encryption in the future:
  # boot.initrd.luks.devices = { ... };

  # Or if surface gets swap:
  # swapDevices = [ ... ];
}
