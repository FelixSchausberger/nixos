{
  lib,
  pkgs,
  inputs,
  ...
}: {
  # VMware VM profile with niri window manager support
  imports = [
    ../../../modules/home/work/git.nix # Add work git config
    ./vmware-clipboard.nix
  ];

  wm.niri = {
    enable = true;
    browser = "zen";
    terminal = "ghostty";
    fileManager = "cosmic-files";
  };

  # Feature-based configuration for development environment
  features = {
    development = {
      enable = true;
      languages = ["nix"];
    };

    gaming = {
      enable = true;
      platforms = ["minecraft"];
    };
  };

  # Enable OpenChamber with Cloudflare tunnel for remote AI coding access
  # TODO: Fix openchamber package availability issue
  # ai-assistants.opencode.openchamber = {
  #   enable = true;
  #   password = "vmware-dev";
  #   enableCloudflare = true;
  #   enableQrCode = true;
  #   autoStart = false;
  # };

  # Fix missing calendar configuration
  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";

  # Home configuration for VMware VM
  programs = {
    # Enable good morning message at 7am
    claude-code.goodMorning = {
      enable = true;
      time = "07:00:00";
      message = "Good morning! Ready to start the day.";
    };

    # Enable direnv for project-specific environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Enhanced shell experience
    fish.enable = true;
    starship.enable = true;
    zoxide.enable = true;

    # Git configuration
    git.enable = true;

    # VMware-specific browser configuration handled via wrapper scripts below
    # (Declarative settings disabled - zen-browser module not available in profile context)

    # VMware display configuration for optimal 1080p fullscreen
    # Explicitly set resolution to match HP VH240a external monitor (1920x1080)
    # Without this, Niri auto-detects and uses VMware's preferred 1280x800
    niri.settings.outputs."Virtual-1" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 60.0;
      };
      scale = 1.0;
      position = {
        x = 0;
        y = 0;
      };
    };
  };

  # VM-specific home configuration
  home = {
    # Useful packages for VM environment
    packages = with pkgs; [
      lazyssh # Terminal-based SSH manager
    ];

    # Environment variables for native Wayland
    sessionVariables = {
      # Wayland backend preferences
      GDK_BACKEND = lib.mkDefault "wayland,x11";
      QT_QPA_PLATFORM = lib.mkDefault "wayland;xcb";

      # Native niri will use DRM/KMS backend automatically
      # No need for NIRI_BACKEND=winit (that's WSL-specific)
    };
  };

  # Enable VMware clipboard bridge for Wayland
  wm.vmwareClipboard.enable = true;

  # VMware-specific workaround for Firefox/Zen WebGL hardware acceleration
  # Problem: VMware vmwgfx driver has working GLX but broken EGL implementation
  # - System GL (GLX via X11): Hardware acceleration works (glxinfo shows SVGA3D)
  # - Browser WebGL (EGL via Wayland): Software rendering (about:support shows llvmpipe)
  #
  # Root causes:
  # 1. Firefox on Wayland uses EGL, which is broken/incomplete in vmwgfx driver
  # 2. Firefox blocklists VMware GPU vendor (only allows Intel/AMD/NVIDIA/Parallels)
  #
  # Solution: Two-part workaround
  # 1. Force X11 backend to use working GLX path instead of broken EGL
  # 2. Spoof GPU vendor ID to bypass Firefox's hard-coded blocklist
  #
  # This wrapper overrides MOZ_ENABLE_WAYLAND=1 (set system-wide) for Zen browser only
  # xwayland-satellite provides X11 display :0 without authentication requirements
  home.file.".local/bin/zen-beta" = {
    executable = true;
    text = ''
      #!/bin/sh
      # VMware GLX workaround: Force X11 backend for hardware-accelerated WebGL
      export GDK_BACKEND=x11
      export MOZ_ENABLE_WAYLAND=0
      export DISPLAY=:0

      # Bypass Firefox GPU blocklist for VMware drivers
      # Firefox blocklists all vendors except Intel/AMD/NVIDIA/Parallels
      # Spoofing vendor ID as 0 bypasses the blocklist while preserving driver functionality
      export MOZ_GFX_SPOOF_VENDOR_ID=0

      exec ${inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/zen-beta "$@"
    '';
  };

  home.file.".local/bin/zen" = {
    executable = true;
    text = ''
      #!/bin/sh
      # Symlink to zen-beta wrapper
      exec ~/.local/bin/zen-beta "$@"
    '';
  };
}
