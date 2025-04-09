{
  # Import the shared boot-zfs.nix configuration
  imports = [../boot-zfs.nix];

  # Desktop-specific boot configuration overrides
  boot.loader.grub.device = "/dev/nvme0n1"; # You can override this if needed

  # Add any desktop-specific configurations here
  # For example, if desktop gets encryption in the future:
  # boot.initrd.luks.devices = { ... };

  # Or if desktop gets swap:
  # swapDevices = [ ... ];
}
