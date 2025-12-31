# Disko configuration for hp-probook-wsl host
#
# WSL-specific configuration - minimal disko setup
# WSL manages its own virtual disk and filesystem automatically
# This configuration is primarily for documentation and consistency
#
# NOTE: Do NOT use disko-install for WSL!
# WSL handles disk management through the Windows host.
# This file exists for:
# - Documentation of the WSL disk layout
# - Consistency with other hosts
# - Potential future WSL reinstalls using disko
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # WSL uses a virtual disk managed by Windows
        # Typically /dev/sdc or similar, auto-created by WSL
        device = "/dev/disk/by-label/nixos";
        content = {
          type = "gpt";
          partitions = {
            # WSL creates a single ext4 partition
            # No EFI partition needed - WSL doesn't use traditional boot
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                ];
              };
            };
          };
        };
      };
    };
  };
}
