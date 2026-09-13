# System modules for GUI hosts (desktop, surface, work machines).
{
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Import TUI base modules first
    ./tui.nix

    # Add GUI-specific modules
    ./display-manager.nix
  ];

  # Desktop conveniences for managed graphical hosts. These are deliberately
  # NOT part of the window-manager modules: a compositor does not require a
  # print service or a firmware daemon, and an on-demand session (a host that
  # keeps the GUI stack available but starts it only when a display appears)
  # should not inherit them. Hosts that want the session on demand import the
  # WM module directly and stay on the TUI baseline.
  config = {
    services = {
      udev.packages = with pkgs; [
        gnome-settings-daemon # For consistent hardware handling
      ];

      upower.enable = true;

      # thermald is force-controlled by hardware.profiles.powerManagement when
      # that profile is enabled (Intel desktops); mkDefault covers GUI hosts
      # that do not use the profile (e.g. laptops).
      thermald.enable = lib.mkDefault true;

      printing.enable = true;
      geoclue2.enable = true;
      tumbler.enable = true;
      gnome.gnome-keyring.enable = true;
      gvfs.enable = true;
      udisks2.enable = true;
      smartd.enable = true;
    };

    # Firmware updates are a hardware concern with its own module; GUI hosts
    # opt in by default.
    modules.system.firmware.enable = lib.mkDefault true;
  };
}
