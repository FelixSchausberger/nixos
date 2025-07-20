{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  config = lib.mkIf cfg.enable {
    # Gaming-specific packages (only included when this module is imported)
    home.packages = with pkgs; [
      # Core gaming
      steam
      lutris
      bottles
      heroic

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

      # Game development
      godot_4

      # Streaming
      obs-studio
      obs-studio-plugins.obs-vkcapture

      # Communication
      discord
      teamspeak_client

      # Tools
      winetricks
      protontricks
      steamtinkerlaunch
    ];

    # Gaming-optimized Hyprland settings
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

        # MangoHud
        "MANGOHUD,1"
        "MANGOHUD_DLSYM,1"

        # GameMode
        "LD_PRELOAD,${pkgs.gamemode}/lib/libgamemodeauto.so.0"
      ];

      # Gaming-specific window rules
      windowrulev2 = [
        # Steam
        "workspace 7,class:^(steam)$"
        "workspace 7,class:^(Steam)$"
        "float,class:^(steam)$,title:^(Friends List)$"
        "float,class:^(steam)$,title:^(Steam Settings)$"
        "float,class:^(steam)$,title:^(Screenshot Uploader)$"
        "float,class:^(steam)$,title:^(Steam Guard)$"

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
        "forceinput,class:^(steam_app_).*"
        "dimaround,class:^(steam_app_).*"
        "idleinhibit focus,class:^(steam_app_).*"

        # Lutris
        "workspace 7,class:^(lutris)$"
        "workspace 7,class:^(Lutris)$"
        "float,class:^(lutris)$,title:^(Lutris)$"

        # Lutris games
        "fullscreen,class:^(lutris-wrapper)$"
        "immediate,class:^(lutris-wrapper)$"
        "allowsinput,class:^(lutris-wrapper)$"
        "idleinhibit focus,class:^(lutris-wrapper)$"

        # Heroic Games Launcher
        "workspace 7,class:^(heroic)$"
        "workspace 7,class:^(Heroic Games Launcher)$"

        # Bottles
        "workspace 7,class:^(com.usebottles.bottles)$"
        "float,class:^(com.usebottles.bottles)$,title:^(Bottles)$"

        # Game development
        "workspace 3,class:^(Godot)$"
        "workspace 3,class:^(godot)$"

        # Emulators
        "workspace 7,class:^(dolphin-emu)$"
        "workspace 7,class:^(PCSX2)$"
        "workspace 7,class:^(rpcs3)$"
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
        "workspace 7,class:^(org.prismlauncher.PrismLauncher)$"
        "workspace 7,class:^(Minecraft)$"
        "fullscreen,class:^(Minecraft)$"
        "immediate,class:^(Minecraft)$"
        "idleinhibit focus,class:^(Minecraft)$"

        # Discord (gaming communication)
        "workspace 6,class:^(discord)$"
        "workspace 6,class:^(Discord)$"
        "workspace 6,class:^(WebCord)$"

        # OBS Studio
        "workspace 8,class:^(obs)$"
        "workspace 8,class:^(com.obsproject.Studio)$"
        "float,class:^(obs)$,title:^(Settings)$"
        "float,class:^(obs)$,title:^(Projector)$"

        # MangoHud settings
        "float,class:^(mangohud)$"
        "float,class:^(goverlay)$"

        # Game performance - disable effects for all games
        "noanim,class:^(steam_app_).*"
        "noanim,class:^(lutris-wrapper)$"
        "noanim,class:^(Minecraft)$"
        "noanim,class:^(dolphin-emu)$"
        "noanim,class:^(PCSX2)$"
        "noanim,class:^(rpcs3)$"
      ];

      # Gaming-optimized workspace rules
      workspace = [
        "7, defaultName:Gaming, persistent:true, monitor:HDMI-A-1"
      ];

      # Gaming-specific keybinds
      bind = [
        # Game mode toggle (disable compositor effects)
        "$mod SHIFT, G, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl keyword decoration:blur:enabled false && ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl keyword animations:enabled false"
        "$mod SHIFT ALT, G, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl keyword decoration:blur:enabled true && ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl keyword animations:enabled true"

        # Quick launch games
        "$mod, G, exec, steam"
        "$mod SHIFT, L, exec, lutris"
        "$mod SHIFT, H, exec, heroic"
        "$mod SHIFT, M, exec, prismlauncher"

        # Gaming utilities
        "$mod CTRL, M, exec, mangohud"
        "$mod CTRL, O, exec, obs"

        # Discord overlay toggle
        "$mod, TAB, exec, ${pkgs.discord}/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland"
      ];

      # Gaming performance optimizations
      misc = {
        # Disable VRR for consistent gaming performance
        vrr = lib.mkForce 0;

        # Gaming-specific optimizations
        # no_direct_scanout = false;
        # render_ahead_of_time = true;
        # render_ahead_safezone = 2;

        # Reduce input lag
        mouse_move_enables_dpms = lib.mkForce false;
        key_press_enables_dpms = lib.mkForce false;

        # Gaming focus
        always_follow_on_dnd = lib.mkForce false;
        animate_manual_resizes = lib.mkForce false;
        animate_mouse_windowdragging = lib.mkForce false;

        # Performance
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        force_default_wallpaper = 0;

        # Gaming-specific background
        background_color = lib.mkForce "0x000000";
      };

      # Optimized decorations for gaming
      decoration = {
        # Disable blur for better performance in games
        blur = {
          enabled = false;
        };

        # Minimal shadows for games
        drop_shadow = false;

        # Simple rounding
        rounding = 0;
      };

      # Gaming-optimized animations (disabled during gameplay)
      animations = {
        enabled = false;
      };

      # Gaming input optimizations
      input = {
        # Gaming mouse settings
        sensitivity = 0;
        accel_profile = "flat";
        force_no_accel = true;

        # Reduce input lag
        follow_mouse = 2;
        mouse_refocus = true;

        # Gaming keyboard
        repeat_rate = 50;
        repeat_delay = 200;

        # Disable touchpad during gaming
        touchpad = {
          disable_while_typing = true;
        };
      };
    };

    # Gaming services
    services = {
      # Gamemode for automatic game performance optimization
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
      "${config.home.homeDirectory}/Documents/Gaming/Screenshots/.keep".text = "";
      "${config.home.homeDirectory}/Documents/Gaming/Recordings/.keep".text = "";
    };
  };
}
