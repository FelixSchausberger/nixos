# Shared baseline for GUI-capable hosts.
# Combines common host defaults, ZFS boot behavior, and system GUI module imports.
# The graphics stack itself is declared by hosts/shared.nix.
{
  imports = [
    ./shared.nix
    ./boot-zfs.nix
    ../modules/system/gui.nix
  ];
}
