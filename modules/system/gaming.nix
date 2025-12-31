{pkgs, ...}: {
  # Centralized gaming and performance optimizations
  # This module provides gaming hardware support and performance tuning

  # Gaming hardware support
  hardware.steam-hardware.enable = true;

  # Enable nix-ld for running non-NixOS binaries (Minecraft Java runtimes, etc.)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Graphics and OpenGL
      libGL
      mesa
      libdrm
      vulkan-loader

      # X11 and Wayland display
      xorg.libX11
      xorg.libxcb
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXrandr
      xorg.libXScrnSaver
      xorg.libXtst
      xorg.libXi
      xorg.libXcursor
      libxkbcommon
      wayland

      # GUI toolkits
      gtk3
      glib
      cairo
      pango
      atk
      gdk-pixbuf

      # Core system libraries
      stdenv.cc.cc
      zlib
      fontconfig
      freetype
      dbus
      expat
      libuuid

      # Audio
      alsa-lib
      pipewire
      libpulseaudio

      # Security and networking
      nss
      nspr
      cups

      # Additional dependencies for Java/Minecraft
      at-spi2-atk
      at-spi2-core
    ];
  };

  # Security configuration for better gaming performance
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

  # GameMode for automatic game optimizations
  programs.gamemode = {
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
}
