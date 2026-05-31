{
  config,
  hostConfig ? {},
  pkgs,
  lib,
  ...
}: let
  safeNotifySend = import ../../lib/safe-notify-send.nix {inherit pkgs config lib;};
  safeNotifyBin = "${safeNotifySend}/bin/safe-notify-send";
in
  lib.optionalAttrs (builtins.elem "hyprland" (hostConfig.wms or [])) {
    # Desktop-specific Hyprland configuration
    wm.hyprland = {
      # Monitor configuration for desktop setup
      # Headless display pre-configured for Sunshine/Moonlight streaming (Pixel 9a: 1080x2400)
      # Created dynamically via `hyprctl output create headless` on boot
      monitors = [
        ",preferred,auto,1" # Real monitor (auto-detect when connected)
        "HEADLESS-1,1920x1080@60,auto,1" # Virtual display for remote streaming
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

      # Emulation
      dolphin-emu
      pcsx2
      rpcs3

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

      # Create headless output for Sunshine/Moonlight remote streaming
      exec-once = ["hyprctl output create headless"];

      # Streaming-optimized cursor settings
      # Hide cursor on key press to reduce encoding overhead during gameplay
      cursor = {
        hide_on_key_press = true;
        hide_on_touch = true;
        no_hardware_cursors = false;
      };

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

        # Steam games - fullscreen, disable effects for streaming performance
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

        # Lutris games - same streaming optimizations
        "fullscreen,class:^(lutris-wrapper)$"
        "immediate,class:^(lutris-wrapper)$"
        "allowsinput,class:^(lutris-wrapper)$"
        "noborder,class:^(lutris-wrapper)$"
        "noanim,class:^(lutris-wrapper)$"
        "noblur,class:^(lutris-wrapper)$"
        "noshadow,class:^(lutris-wrapper)$"
        "opaque,class:^(lutris-wrapper)$"
        "idleinhibit focus,class:^(lutris-wrapper)$"

        # Bottles
        "float,class:^(com.usebottles.bottles)$,title:^(Bottles)$"

        # Emulators - fullscreen with streaming optimizations
        "fullscreen,class:^(dolphin-emu)$"
        "fullscreen,class:^(PCSX2)$"
        "fullscreen,class:^(rpcs3)$"
        "immediate,class:^(dolphin-emu)$"
        "immediate,class:^(PCSX2)$"
        "immediate,class:^(rpcs3)$"
        "noborder,class:^(dolphin-emu)$"
        "noborder,class:^(PCSX2)$"
        "noborder,class:^(rpcs3)$"
        "noanim,class:^(dolphin-emu)$"
        "noanim,class:^(PCSX2)$"
        "noanim,class:^(rpcs3)$"
        "noblur,class:^(dolphin-emu)$"
        "noblur,class:^(PCSX2)$"
        "noblur,class:^(rpcs3)$"
        "noshadow,class:^(dolphin-emu)$"
        "noshadow,class:^(PCSX2)$"
        "noshadow,class:^(rpcs3)$"
        "opaque,class:^(dolphin-emu)$"
        "opaque,class:^(PCSX2)$"
        "opaque,class:^(rpcs3)$"
        "idleinhibit focus,class:^(dolphin-emu)$"
        "idleinhibit focus,class:^(PCSX2)$"
        "idleinhibit focus,class:^(rpcs3)$"

        # Minecraft
        "fullscreen,class:^(Minecraft)$"
        "immediate,class:^(Minecraft)$"
        "noborder,class:^(Minecraft)$"
        "noanim,class:^(Minecraft)$"
        "noblur,class:^(Minecraft)$"
        "noshadow,class:^(Minecraft)$"
        "opaque,class:^(Minecraft)$"
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
    # Note: Steam auto-start disabled for boot performance
    # Launch Steam manually via application menu or `steam` command
    systemd.user.services = {};

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
        start=${safeNotifyBin} "GameMode activated"
        end=${safeNotifyBin} "GameMode deactivated"
      '';
    };

    # Create gaming directories
    home.file = {
      "${config.home.homeDirectory}/Documents/Gaming/.keep".text = "";
      "${config.home.homeDirectory}/Documents/Gaming/MangoHud/.keep".text = "";
    };
  }
