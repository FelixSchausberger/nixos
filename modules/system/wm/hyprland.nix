{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.hyprland.nixosModules.default
  ];

  # Enable Hyprland with optimal settings
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  # XDG Portal configuration - let programs.hyprland handle the service creation
  xdg.portal = {
    enable = true;
    wlr.enable = true;

    # Use Hyprland portal as primary, with GTK as fallback for file operations
    config = {
      common = {
        default = ["hyprland" "gtk"];
      };
      hyprland = {
        default = ["hyprland" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
        "org.freedesktop.impl.portal.AppChooser" = ["gtk"];
        "org.freedesktop.impl.portal.Print" = ["gtk"];
        "org.freedesktop.impl.portal.Settings" = ["gtk"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Inhibit" = ["hyprland"];
      };
    };

    extraPortals = with pkgs; [
      # Don't manually add xdg-desktop-portal-hyprland here - let programs.hyprland handle it
      xdg-desktop-portal-gtk # File picker and app chooser
      xdg-desktop-portal-wlr # Additional Wayland support
    ];
  };

  # Session management and authentication
  security = {
    # PAM configuration for hyprlock
    pam.services = {
      hyprlock = {
        text = ''
          auth include login
        '';
      };
      # Enable hyprlock to work with login
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

  # System packages required for Hyprland
  environment.systemPackages = with pkgs; [
    # Core Wayland
    wayland
    wayland-protocols
    wayland-utils
    wlroots

    # Hyprland ecosystem
    hyprland-protocols
    hyprpicker
    hyprpaper
    hypridle
    hyprlock

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

    # Screenshot and recording
    grim
    slurp
    swappy

    # Development and utilities
    jq # For Hyprland scripting
    socat # For Hyprland IPC

    # Theme support
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
    libsForQt5.qt5ct
    qt6ct

    # Portal dependencies (xdg-desktop-portal-hyprland provided by programs.hyprland)
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
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

  # System-wide environment variables
  environment.sessionVariables = {
    # Hyprland
    HYPRLAND_TRACE = "1"; # Enables more verbose logging.

    # Aquamarine
    AQ_TRACE = "1"; # Enables more verbose logging.

    # Wayland
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";

    # Qt
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1";

    # GTK
    GDK_BACKEND = "wayland,x11";
    GDK_SCALE = "1";

    # Mozilla
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_WEBRENDER = "1";
    MOZ_ACCELERATED = "1";

    # XDG
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
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
