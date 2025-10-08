{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.niri.nixosModules.niri
    ./shared-environment.nix
  ];

  # Enable niri
  programs.niri = {
    enable = true;
    # Enable xwayland for compatibility with X11 applications
    package = pkgs.niri;
  };

  # Session management and authentication
  security = {
    # PAM configuration for screen locking
    pam.services = {
      login.enableGnomeKeyring = true;
    };

    # Polkit for privilege escalation
    polkit.enable = true;
    rtkit.enable = true;
  };

  # Audio system (required for proper Wayland audio)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Low-latency configuration
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock = {
          rate = 48000;
          quantum = 32;
          min-quantum = 32;
          max-quantum = 32;
        };
      };
    };
  };

  # System packages required for niri
  environment.systemPackages = with pkgs; [
    # Core Wayland
    wayland
    wayland-protocols
    wayland-utils
    wlroots
    egl-wayland # EGL Wayland platform

    # X11/Wayland compatibility
    inputs.niri.packages.${pkgs.system}.xwayland-satellite-unstable

    # System utilities
    wl-clipboard
    wl-clip-persist
    cliphist

    # File managers
    xdg-utils

    # System monitoring and control
    brightnessctl
    playerctl
    pavucontrol

    # Screenshot tools
    grim
    slurp
    swappy

    # Development and utilities
    jq # For scripting
    socat # For IPC

    # Theme support
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
    libsForQt5.qt5ct
    qt6ct

    # Portal dependencies
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gnome

    # Cursor themes
    adwaita-icon-theme
    bibata-cursors
  ];

  # Fonts configuration
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      font-awesome
      noto-fonts
      noto-fonts-emoji
      noto-fonts-cjk-sans
      liberation_ttf
      fira-code
      fira-code-symbols
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.meslo-lg
    ];

    fontconfig = {
      enable = true;
      antialias = true;
      cache32Bit = true;
      hinting.enable = true;
      hinting.style = "slight";
      subpixel.rgba = "rgb";

      defaultFonts = {
        serif = ["Noto Serif" "Liberation Serif"];
        sansSerif = ["Noto Sans" "Liberation Sans"];
        monospace = ["JetBrainsMono Nerd Font" "Liberation Mono"];
        emoji = ["Noto Color Emoji"];
      };
    };
  };

  # Niri-specific environment variables
  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = lib.mkDefault "niri";
    XDG_SESSION_DESKTOP = lib.mkDefault "niri";
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

  # Security configuration
  security.pam.loginLimits = [
    # Real-time scheduling for better audio/gaming performance
    {
      domain = "@users";
      item = "rtprio";
      type = "-";
      value = "1";
    }
    {
      domain = "@users";
      item = "nice";
      type = "-";
      value = "-11";
    }
    {
      domain = "@users";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];

  # Gaming and performance optimizations (system-level)
  programs = {
    # GameMode for automatic game optimizations
    gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
          ioprio = 4;
          inhibit_screensaver = 1;
        };

        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };
  };

  # Virtual console configuration for better Wayland experience
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [terminus_font];
    keyMap = "us";
  };
}
