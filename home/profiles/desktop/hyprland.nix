{
  config,
  pkgs,
  ...
}: {
  # Desktop-specific Hyprland configuration
  wm.hyprland = {
    # Monitor configuration for desktop setup
    # Using auto-detection as default - can be overridden for specific multi-monitor setups
    monitors = [
      ",preferred,auto,1"
      # Add specific monitor configs here if needed, e.g.:
      # "DP-1,2560x1440@144,0x0,1"
      # "HDMI-A-1,1920x1080@60,2560x0,1"
    ];

    # Desktop-specific application preferences
    browser = "zen";
    terminal = "ghostty";
    fileManager = "cosmic-files";

    # Desktop-specific scratchpad preferences
    scratchpad = {
      musicApp = "spotify"; # Full Spotify for desktop
      notesApp = "obsidian"; # Full note-taking app
    };
  };

  # Desktop-specific packages (gaming and productivity)
  home.packages = with pkgs; [
    # Core gaming
    steam
    lutris
    bottles

    # Performance monitoring and optimization
    mangohud
    goverlay
    gamemode
    gamescope

    # Game launchers
    prismlauncher # Minecraft

    # Emulation (all temporarily disabled due to Qt 6.10 incompatibility)
    # dolphin-emu # Temporarily disabled: Qt 6.10 incompatibility causing build failures
    # pcsx2 # Temporarily disabled: Qt 6.10 incompatibility causing build failures
    # rpcs3 # Temporarily disabled: strict-aliasing compilation errors

    # Communication
    discord

    # Tools
    winetricks
    protontricks
    steamtinkerlaunch
  ];

  # Desktop-specific Hyprland configuration
  wayland.windowManager.hyprland.settings = {
    # Gaming environment variables
    env = [
      # Steam optimizations
      "STEAM_EXTRA_COMPAT_TOOLS_PATHS,${config.home.homeDirectory}/.steam/root/compatibilitytools.d"

      # AMD GPU gaming optimizations
      "AMD_VULKAN_ICD,RADV"
      "RADV_PERFTEST,gpl,nggc,sam"
      "RADV_DEBUG,novrsflatshading"

      # Mesa optimizations
      "MESA_VK_VERSION_OVERRIDE,1.3"
      "mesa_glthread,true"

      # Game performance
      "__GL_THREADED_OPTIMIZATIONS,1"
      "__GL_SHADER_DISK_CACHE,1"
      "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP,1"

      # Wayland gaming
      "SDL_VIDEODRIVER,wayland"
      "QT_QPA_PLATFORM,wayland;xcb"

      # MangoHud - disabled globally (use per-application instead)
      # "MANGOHUD,1"
      "MANGOHUD_DLSYM,1"

      # GameMode is handled automatically by the system-level gamemode service
      # No need for manual LD_PRELOAD - gamemode daemon handles this
    ];

    # Desktop-specific window rules (including gaming)
    windowrulev2 = [
      # Steam - float dialogs/popups only
      "float,class:^(steam)$,title:^(Friends List)$"
      "float,class:^(steam)$,title:^(Steam Settings)$"
      "float,class:^(steam)$,title:^(Screenshot Uploader)$"
      "float,class:^(steam)$,title:^(Steam Guard)$"
      "float,class:^(steam)$,title:^(Steam - News)$"
      "float,class:^(steam)$,title:^(Special Offers)$"
      "float,class:^(steam)$,title:^(Steam Cloud)$"

      # Steam games - fullscreen and performance optimizations
      "fullscreen,class:^(steam_app_).*"
      "immediate,class:^(steam_app_).*"
      "allowsinput,class:^(steam_app_).*"
      "noborder,class:^(steam_app_).*"
      "noanim,class:^(steam_app_).*"
      "noblur,class:^(steam_app_).*"
      "noshadow,class:^(steam_app_).*"
      "norounding,class:^(steam_app_).*"
      "opaque,class:^(steam_app_).*"
      "dimaround,class:^(steam_app_).*"
      "idleinhibit focus,class:^(steam_app_).*"

      # Lutris
      "float,class:^(lutris)$,title:^(Lutris)$"

      # Lutris games
      "fullscreen,class:^(lutris-wrapper)$"
      "immediate,class:^(lutris-wrapper)$"
      "allowsinput,class:^(lutris-wrapper)$"
      "idleinhibit focus,class:^(lutris-wrapper)$"

      # Bottles
      "float,class:^(com.usebottles.bottles)$,title:^(Bottles)$"

      # Emulators
      "fullscreen,class:^(dolphin-emu)$"
      "fullscreen,class:^(PCSX2)$"
      "fullscreen,class:^(rpcs3)$"
      "immediate,class:^(dolphin-emu)$"
      "immediate,class:^(PCSX2)$"
      "immediate,class:^(rpcs3)$"
      "idleinhibit focus,class:^(dolphin-emu)$"
      "idleinhibit focus,class:^(PCSX2)$"
      "idleinhibit focus,class:^(rpcs3)$"

      # Minecraft
      "fullscreen,class:^(Minecraft)$"
      "immediate,class:^(Minecraft)$"
      "idleinhibit focus,class:^(Minecraft)$"

      # MangoHud settings
      "float,class:^(mangohud)$"
      "float,class:^(goverlay)$"
    ];

    # Desktop-specific keybinds
    bind = [
      # Quick launch games
      "$mod, G, exec, steam"
      "$mod SHIFT, L, exec, lutris"
      "$mod SHIFT, M, exec, prismlauncher"

      # Gaming utilities
      "$mod CTRL, M, exec, mangohud"

      # Discord overlay toggle
      "$mod, TAB, exec, ${pkgs.discord}/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland"
    ];
  };

  # Gaming-specific systemd services
  systemd.user.services = {
    # Auto-start Steam in background
    steam-background = {
      Unit = {
        Description = "Steam Background Service";
        After = ["hyprland-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.steam}/bin/steam -silent";
        Restart = "no";
        RemainAfterExit = "yes";
      };

      Install.WantedBy = ["hyprland-session.target"];
    };
  };

  # Gaming configuration files
  xdg.configFile = {
    # MangoHud configuration
    "MangoHud/MangoHud.conf".text = ''
      # Performance monitoring
      fps
      frametime
      cpu_temp
      gpu_temp
      cpu_power
      gpu_power
      ram
      vram

      # Position and appearance
      position=top-left
      width=400
      height=200
      font_size=16
      background_alpha=0.4
      alpha=0.8

      # Data logging
      output_folder=${config.home.homeDirectory}/Documents/Gaming/MangoHud
      log_duration=60
      autostart_log=0

      # Networking
      no_display=0

      # Control
      toggle_fps_limit=F1
      toggle_logging=F2
      reload_cfg=F4
      upload_log=F5
    '';

    # GameMode configuration
    "gamemode.ini".text = ''
      [general]
      renice=10
      ioprio=4
      inhibit_screensaver=1

      [filter]
      whitelist=steam
      whitelist=lutris
      whitelist=heroic
      whitelist=prismlauncher

      [gpu]
      apply_gpu_optimisations=accept-responsibility
      gpu_device=0
      amd_performance_level=high

      [custom]
      start=${pkgs.libnotify}/bin/notify-send "GameMode activated"
      end=${pkgs.libnotify}/bin/notify-send "GameMode deactivated"
    '';
  };

  # Create gaming directories
  home.file = {
    "${config.home.homeDirectory}/Documents/Gaming/.keep".text = "";
    "${config.home.homeDirectory}/Documents/Gaming/MangoHud/.keep".text = "";
  };
}
