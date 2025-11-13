{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.hyprland.nixosModules.default
    ./shared-environment.nix
    ./shared-pipewire.nix
    ./shared-packages.nix
    ./shared-security.nix
  ];

  # Enable Hyprland with optimal settings
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  # Hyprland-specific PAM configuration for cthulock
  security.pam.services.cthulock = {
    text = ''
      auth include login
    '';
  };

  # PipeWire, fonts, and common security configuration are provided by shared modules

  # Hyprland-specific system packages (common Wayland packages provided by shared-packages.nix)
  environment.systemPackages = with pkgs; [
    # Core compositor dependency
    wlroots # Wayland compositor library used by Hyprland

    # Hyprland ecosystem
    hyprland-protocols
    hyprpicker

    # Qt theme tools (Hyprland-specific)
    libsForQt5.qt5ct
    qt6Packages.qt6ct

    # Portal dependencies (xdg-desktop-portal-hyprland provided by programs.hyprland)
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
  ];

  # Hyprland-specific environment variables
  environment.sessionVariables = {
    # Hyprland debugging
    HYPRLAND_TRACE = "1"; # Enables more verbose logging.
    AQ_TRACE = "1"; # Aquamarine verbose logging.

    # Override desktop identification for Hyprland
    XDG_CURRENT_DESKTOP = lib.mkForce "Hyprland";
    XDG_SESSION_DESKTOP = lib.mkForce "Hyprland";
  };

  # Services configuration
  services = {
    # Enable dbus for proper IPC
    dbus.enable = true;

    # Enable udev for device management
    udev.enable = true;
    udev.packages = with pkgs; [
      gnome-settings-daemon # For consistent hardware handling
    ];

    # Power management
    upower.enable = true;
    thermald.enable = true;

    # Printing (if needed)
    printing.enable = true;

    # Location services (for gammastep/redshift)
    geoclue2.enable = true;

    # Thumbnail generation
    tumbler.enable = true;

    # GNOME keyring (for credential management)
    gnome.gnome-keyring.enable = true;

    # Auto-mounting
    gvfs.enable = true;
    udisks2.enable = true;

    # Firmware updates
    fwupd.enable = true;

    # System monitoring
    smartd.enable = true;
  };

  # Systemd configuration for better Wayland integration
  systemd = {
    # Systemd user environment
    user.extraConfig = ''
      DefaultEnvironment="PATH=/run/current-system/sw/bin"
    '';
  };

  # Virtual console configuration for better Wayland experience
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [terminus_font];
    keyMap = "us";
  };
}
