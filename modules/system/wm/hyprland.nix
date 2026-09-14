# System-side Hyprland session module integrated with shared Wayland platform settings.
# Enabled only when hostConfig marks Hyprland active on GUI hosts.
{
  pkgs,
  lib,
  hostConfig,
  ...
}: {
  # Note: inputs.hyprland.nixosModules.default is intentionally NOT imported here.
  # It bundles a kmscon module that uses removed nixpkgs API (extraConfig, fonts, autologinUser).
  # Programs.hyprland is provided by nixpkgs instead.
  imports = [
    ../session/default.nix
    ../session/hyprland.nix
    ./shared-environment.nix
    ./shared-pipewire.nix
    ./shared-packages.nix
    ./shared-security.nix
  ];

  # isGui skips this module on TUI-only hosts; builtins.elem skips it when
  # this WM is not active, keeping specialisation evaluation cheap.
  config = lib.mkIf (hostConfig.isGui && builtins.elem "hyprland" hostConfig.wms) {
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

    # Services configuration. Only what the session itself needs; desktop
    # conveniences (printing, firmware, gvfs, power, thumbnails, keyring) are
    # separate concerns declared in modules/system/gui.nix and
    # modules/system/firmware.nix.
    services = {
      # Enable dbus for proper IPC
      dbus.enable = true;

      # Enable udev for device management
      udev.enable = true;
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
  };
}
