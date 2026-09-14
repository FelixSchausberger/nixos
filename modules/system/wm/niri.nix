# System-side Niri session module integrated with shared Wayland platform settings.
# Enabled only when hostConfig marks Niri active on GUI hosts.
{
  inputs,
  pkgs,
  lib,
  hostConfig,
  ...
}: {
  imports = [
    inputs.niri.nixosModules.niri
    ../session/default.nix
    ../session/niri.nix
    ./shared-environment.nix
    ./shared-pipewire.nix
    ./shared-packages.nix
    ./shared-security.nix
  ];

  # isGui skips this module on TUI-only hosts; builtins.elem skips it when
  # this WM is not active, keeping specialisation evaluation cheap.
  config = lib.mkIf (hostConfig.isGui && builtins.elem "niri" hostConfig.wms) {
    # Enable niri
    programs.niri = {
      enable = true;
      # Enable xwayland for compatibility with X11 applications
      package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
    };

    # PipeWire, fonts, and common security configuration are provided by shared modules

    # Niri-specific system packages (common Wayland packages provided by shared-packages.nix)
    environment.systemPackages = with pkgs; [
      # Niri-specific Wayland components
      egl-wayland # EGL Wayland platform

      # X11/Wayland compatibility (Niri-specific)
      inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite-unstable

      # Qt theme tools (Niri-specific)
      libsForQt5.qt5ct
      qt6Packages.qt6ct

      # Portal dependencies (Niri-specific portals)
      xdg-desktop-portal
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gnome

      # Cursor and icon themes (Niri-specific)
      adwaita-icon-theme
      bibata-cursors
    ];

    # Niri-specific environment variables
    environment.sessionVariables = {
      XDG_CURRENT_DESKTOP = lib.mkDefault "niri";
      XDG_SESSION_DESKTOP = lib.mkDefault "niri";
    };

    # Services configuration. Only what the session itself needs; desktop
    # conveniences (printing, firmware, gvfs, power, thumbnails, keyring) are
    # separate concerns declared in modules/system/gui.nix and
    # modules/system/firmware.nix so a session does not drag them in.
    services = {
      # Enable dbus for proper IPC
      dbus.enable = true;

      # Enable udev for device management
      udev.enable = true;
    };

    # Systemd configuration for better Wayland integration
    systemd = {
      # Systemd user environment
      user.settings.Manager.DefaultEnvironment = "PATH=/run/current-system/sw/bin";

      # X11 directory with sticky bit for xwayland-satellite
      tmpfiles.rules = [
        "d /tmp/.X11-unix 1777 root root -"
      ];
    };

    # Virtual console configuration for better Wayland experience
    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
      packages = with pkgs; [terminus_font];
      keyMap = lib.mkDefault "us";
    };
  };
}
