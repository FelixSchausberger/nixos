{
  lib,
  pkgs,
  config,
  inputs,
  hostName ? "unknown",
  ...
}: let
  cfg = config.wm.hyprland;
  isDesktop = hostName == "desktop";

  # Package mappings for applications
  browserPkg =
    if cfg.browser == "zen"
    then inputs.zen-browser.packages.${pkgs.system}.default
    else if cfg.browser == "firefox"
    then pkgs.firefox
    else if cfg.browser == "chromium"
    then pkgs.chromium
    else pkgs.firefox;

  terminalPkg =
    if cfg.terminal == "ghostty"
    then inputs.ghostty.packages.${pkgs.system}.default
    else if cfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if cfg.terminal == "wezterm"
    then pkgs.wezterm
    else inputs.ghostty.packages.${pkgs.system}.default;

  fileManagerPkg =
    if cfg.fileManager == "cosmic-files"
    then pkgs.cosmic-files
    else if cfg.fileManager == "nautilus"
    then pkgs.nautilus
    else if cfg.fileManager == "thunar"
    then pkgs.xfce.thunar
    else pkgs.cosmic-files;
in {
  imports =
    [
      # Using correct homeManagerModules attribute
      inputs.cosmic-manager.homeManagerModules.default
      inputs.wayland-pipewire-idle-inhibit.homeModules.default
      ./animations.nix
      ./ironbar.nix # Customizable gtk-layer-shell wlroots/sway bar written in Rust
      ./keybinds.nix
      ./scratchpads.nix
      ./swaync.nix # Modern notification daemon
      ./walker.nix # Wayland-native application launcher
      ./workspaces.nix
    ]
    ++ lib.optionals isDesktop [
      ./gaming.nix
    ];

  options.wm.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager" // {default = true;};

    terminal = lib.mkOption {
      type = lib.types.str;
      default = "ghostty";
      description = "Default terminal emulator";
      example = "cosmic-term, ghostty, wezterm";
    };

    browser = lib.mkOption {
      type = lib.types.str;
      default = "zen";
      description = "Default browser";
      example = "zen, firefox, chromium";
    };

    fileManager = lib.mkOption {
      type = lib.types.str;
      default = "cosmic-files";
      description = "Default file manager";
      example = "cosmic-files, nautilus, thunar";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["eDP-1,1920x1080@60,0x0,1"];
      description = "Monitor configuration";
      example = [
        "HDMI-A-1,1920x1080@60,0x0,1"
        "eDP-1,1920x1080@60,1920x0,1"
      ];
    };

    scratchpad = {
      notesApp = lib.mkOption {
        type = lib.types.enum ["obsidian" "basalt"];
        default = "obsidian";
        description = "Notes application for scratchpad";
      };

      musicApp = lib.mkOption {
        type = lib.types.enum ["spotify" "spotify-player"];
        default = "spotify";
        description = "Music application for scratchpad";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs;
      [
        # Core Hyprland utilities
        hyprpicker # Color picker
        hyprcursor # Cursor theme
        hyprpaper # Wallpaper utility
        hyprlock # Screen locker
        hypridle # Idle daemon
        hyprsunset # Blue light filter
        hyprpolkitagent # Authentication agent

        # Screenshots and media
        grim # Screenshot utility
        slurp # Region selection
        swappy # Screenshot annotation
        wf-recorder # Screen recording

        # System utilities
        wl-clipboard # Wayland clipboard
        cliphist # Clipboard history
        avizo # OSD for volume/brightness
        playerctl # Media control
        pavucontrol # Audio control
        inputs.bluetui.packages.${pkgs.system}.default # Bluetooth management

        # Utilities
        inputs.walker.packages.${pkgs.system}.default # Wayland-native application launcher with plugins
        udiskie # Auto-mount

        # Cursor themes
        adwaita-icon-theme # For Adwaita cursor theme
        bibata-cursors # Better cursor theme
        hyprcursor # Hyprland cursor engine
      ]
      ++ lib.optionals isDesktop [
        # Gaming packages only on desktop
        steam
        lutris
        mangohud
        gamemode
      ];

    wayland.windowManager.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
      plugins = [
        inputs.hyprland-plugins.packages.${pkgs.system}.hyprexpo
      ];

      settings = {
        # Environment variables
        env = [
          "QT_QPA_PLATFORM,wayland"
          "QT_QPA_PLATFORMTHEME,qt6ct"
          "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
          "QT_AUTO_SCREEN_SCALE_FACTOR,1"
          "QT_SCALE_FACTOR,1"

          "GDK_BACKEND,wayland,x11,*"
          "GDK_SCALE,1"

          "XDG_CURRENT_DESKTOP,Hyprland"
          "XDG_SESSION_TYPE,wayland"
          "XDG_SESSION_DESKTOP,Hyprland"

          "MOZ_ENABLE_WAYLAND,1"
          "MOZ_WEBRENDER,1"
          "MOZ_ACCELERATED,1"

          # Application defaults
          "TERMINAL,${terminalPkg}/bin/${cfg.terminal}"
          "BROWSER,${browserPkg}/bin/${
            if cfg.browser == "zen"
            then "zen"
            else cfg.browser
          }"
          "FILEMANAGER,${fileManagerPkg}/bin/${cfg.fileManager}"

          # Cursor configuration
          "XCURSOR_THEME,Bibata-Modern-Classic"
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_THEME,Bibata-Modern-Classic"
          "HYPRCURSOR_SIZE,24"
        ];

        # Monitor configuration
        monitor = cfg.monitors;

        # Variables
        "$mod" = "SUPER";
        "$terminal" = "${terminalPkg}/bin/${cfg.terminal}";
        "$browser" = "${browserPkg}/bin/${
          if cfg.browser == "zen"
          then "zen"
          else cfg.browser
        }";
        "$fileManager" = "${fileManagerPkg}/bin/${cfg.fileManager}";

        # Input configuration
        input = {
          kb_layout = "eu,de";
          kb_variant = ",";
          kb_options = "grp:alt_shift_toggle,terminate:ctrl_alt_bksp";
          kb_model = "pc104";
          follow_mouse = lib.mkDefault 1;
          touchpad = {
            natural_scroll = true;
            disable_while_typing = true;
            tap-to-click = true;
            drag_lock = false;
          };
        };

        # General configuration with improved auto-tiling
        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          "col.active_border" = "rgb(89b4fa) rgb(cba6f7) 45deg";
          "col.inactive_border" = "rgb(45475a)";
          layout = "dwindle";
          allow_tearing = true;
          resize_on_border = true;
          extend_border_grab_area = 15;
        };

        # Enhanced decoration
        decoration = {
          rounding = lib.mkDefault 12;

          blur = {
            enabled = lib.mkDefault true;
            size = 6;
            passes = 3;
            new_optimizations = true;
            ignore_opacity = true;
            noise = 0.1;
            contrast = 1.1;
            brightness = 1.2;
            xray = false;
          };

          shadow = {
            enabled = true;
            range = 20;
            render_power = 3;
            ignore_window = true;
            color = "rgba(1e1e2eee)";
            offset = "0 8";
            scale = 1.0;
          };

          dim_inactive = false;
          dim_strength = 0.1;
        };

        # Improved dwindle layout
        dwindle = {
          pseudotile = true;
          preserve_split = true;
          smart_split = true;
          smart_resizing = true;
          permanent_direction_override = false;
          special_scale_factor = 0.8;
        };

        master = {
          new_status = "master";
          new_on_top = false;
          mfact = 0.5;
        };

        # Gesture configuration
        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
          workspace_swipe_distance = 300;
          workspace_swipe_invert = true;
          workspace_swipe_min_speed_to_force = 30;
          workspace_swipe_cancel_ratio = 0.5;
          workspace_swipe_create_new = false;
        };

        # Group configuration
        group = {
          "col.border_active" = "rgb(cba6f7)";
          "col.border_inactive" = "rgb(45475a)";
          "col.border_locked_active" = "rgb(f38ba8)";
          "col.border_locked_inactive" = "rgb(45475a)";
        };

        # Miscellaneous settings
        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
          enable_swallow = true;
          swallow_regex = "^(${cfg.terminal})$";
          focus_on_activate = true;
          mouse_move_focuses_monitor = true;
        };

        render = {
          direct_scanout = true;
        };

        ecosystem = {
          no_update_news = true;
        };

        plugin = {
          hyprexpo = {
            columns = 3;
            gap_size = 5;
            bg_col = "rgb(111111)";
            workspace_method = "center current";

            enable_gesture = true;
            gesture_fingers = 3;
            gesture_distance = 300;
            gesture_positive = true;
          };
        };

        cursor = {
          min_refresh_rate = 24;
          enable_hyprcursor = true;
          hide_on_key_press = true;
        };

        # XWayland configuration
        xwayland = {
          use_nearest_neighbor = false;
          force_zero_scaling = false;
        };

        # Advanced window rules
        windowrulev2 =
          [
            # Scratchpad rules
            "float,class:^(scratchpad-.*)$"
            "size 80% 80%,class:^(scratchpad-.*)$"
            "center,class:^(scratchpad-.*)$"
            "opacity 0.95,class:^(scratchpad-.*)$"

            # Application-specific rules
            "workspace 2,class:^(${cfg.browser})$"
            "workspace 3,class:^(code-url-handler)$"
            "workspace 3,class:^(Code)$"

            # Floating windows
            "float,class:^(floating-mode)$"
            "float,class:^(pavucontrol)$"
            "float,class:^(it.mijorus.smile)$"
            "float,class:^(org.gnome.Calculator)$"
            "float,class:^(nm-connection-editor)$"

            # Picture-in-picture
            "float,title:^(Picture-in-Picture)$"
            "pin,title:^(Picture-in-Picture)$"
            "move 75% 75%,title:^(Picture-in-Picture)$"
            "size 24% 24%,title:^(Picture-in-Picture)$"

            # Transparency
            "opacity 0.9,class:^(${cfg.terminal})$"
            "opacity 0.95,class:^(${cfg.fileManager})$"
          ]
          ++ lib.optionals isDesktop [
            # Gaming rules (only on desktop)
            "workspace 7,class:^(steam)$"
            "workspace 7,class:^(lutris)$"
            "fullscreen,class:^(steam_app_).*"
            "immediate,class:^(steam_app_).*"
            "allowsinput,class:^(steam_app_).*"
            "noinitialfocus,class:^(steam)$"
          ];

        # Layer rules for better blur effects
        layerrule = [
          "blur,ironbar"
          "ignorezero,ironbar"
          "blur,notifications"
          "blur,walker"
          "blur,gtk-layer-shell"
          "dimaround,walker"
        ];

        # Startup applications
        exec-once = [
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "${pkgs.avizo}/bin/avizo-service"
          "${pkgs.hypridle}/bin/hypridle"
          "${pkgs.hyprpaper}/bin/hyprpaper"
          "${inputs.ironbar.packages.${pkgs.system}.default}/bin/ironbar"
          "${pkgs.udiskie}/bin/udiskie --tray"
          "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store"
          "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store"
          "${pkgs.hyprsunset}/bin/hyprsunset -t 4500"
          "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
          # "${pkgs.networkmanagerapplet}/bin/nm-applet"
          "${pkgs.hyprland-autoname-workspaces}/bin/hyprland-autoname-workspaces"

          # Start on workspace 1 then let window rules assign to correct workspaces
          "sleep 2 && ${browserPkg}/bin/${
            if cfg.browser == "zen"
            then "zen"
            else cfg.browser
          }"
          "sleep 3 && ${pkgs.code-cursor}/bin/cursor"
        ];
      };
    };

    # Configure wayland-pipewire-idle-inhibit service
    services.wayland-pipewire-idle-inhibit = {
      enable = true;
      systemdTarget = "hyprland-session.target";
      settings = {
        verbosity = "INFO";
        media_minimum_duration = 5;
        idle_inhibitor = "wayland";
        # You can customize these filters as needed
        sink_whitelist = [];
        node_blacklist = [
          {name = "spotify";}
          {app_name = "Music Player Daemon";}
        ];
      };
    };

    # XDG configuration files
    xdg.configFile = {
      "hypr/hyprpaper.conf".text = ''
        # Preload wallpaper
        preload = ${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg

        # Set wallpaper for all monitors
        wallpaper = eDP-1,${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg
        wallpaper = ,${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg

        # Configuration
        splash = false
        ipc = on
      '';

      "hypr/hypridle.conf".text = ''
        general {
            lock_cmd = pidof hyprlock || hyprlock
            before_sleep_cmd = loginctl lock-session
            after_sleep_cmd = hyprctl dispatch dpms on
            ignore_dbus_inhibit = false
        }

        listener {
            timeout = 300
            on-timeout = loginctl lock-session
        }

        listener {
            timeout = 330
            on-timeout = hyprctl dispatch dpms off
            on-resume = hyprctl dispatch dpms on
        }

        listener {
            timeout = 1800
            on-timeout = systemctl suspend
        }
      '';

      "hypr/hyprlock.conf".text = ''
        general {
            disable_loading_bar = true
            grace = 300
            hide_cursor = false
            no_fade_in = false
            no_fade_out = false
            ignore_empty_input = false
            immediate_render = false
            pam_module = hyprlock
        }

        background {
            monitor = eDP-1
            path = ${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg
            blur_passes = 3
            blur_size = 8
            noise = 0.0117
            contrast = 0.8916
            brightness = 0.8172
            vibrancy = 0.1696
            vibrancy_darkness = 0.0
        }

        input-field {
            monitor =
            size = 250, 60
            outline_thickness = 2
            dots_size = 0.33
            dots_spacing = 0.15
            dots_center = true
            dots_rounding = -1
            outer_color = rgb(89b4fa)
            inner_color = rgb(1e1e2e)
            font_color = rgb(cdd6f4)
            fade_on_empty = true
            fade_timeout = 1000
            placeholder_text = <i>Password...</i>
            hide_input = false
            rounding = 12
            check_color = rgb(a6e3a1)
            fail_color = rgb(f38ba8)
            fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>
            fail_transition = 300
            capslock_color = -1
            numlock_color = -1
            bothlock_color = -1
            invert_numlock = false
            swap_font_color = false
            position = 0, -80
            halign = center
            valign = center
        }

        label {
            monitor =
            text = $TIME
            color = rgb(cdd6f4)
            font_size = 90
            font_family = JetBrainsMono Nerd Font ExtraBold
            position = 0, 80
            halign = center
            valign = center
            shadow_passes = 5
            shadow_size = 10
        }

        label {
            monitor =
            text = Hi there, $USER
            color = rgb(cdd6f4)
            font_size = 20
            font_family = JetBrainsMono Nerd Font
            position = 0, 0
            halign = center
            valign = center
            shadow_passes = 5
            shadow_size = 10
        }
      '';

      "wallpapers/.keep".text = "";

      # GTK cursor theme configuration
      "gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-cursor-theme-name=Bibata-Modern-Classic
        gtk-cursor-theme-size=24
      '';

      "gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-cursor-theme-name=Bibata-Modern-Classic
        gtk-cursor-theme-size=24
      '';

      # Bluetui configuration
      "bluetui/config.toml".text = ''
        # Bluetui configuration
        toggle_scanning = "s"

        [adapter]
        toggle_pairing = "p"
        toggle_power = "o"
        toggle_discovery = "d"

        [paired_device]
        unpair = "u"
        toggle_connect = " "
        toggle_trust = "t"
        rename = "e"

        [new_device]
        pair = "p"
      '';
    };

    # Copy wallpapers to user config directory
    home.file = {
      "${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg" = {
        source = ../../wallpapers/solar-system.jpg;
      };
      "${config.home.homeDirectory}/.config/wallpapers/the-whale.jpg" = {
        source = ../../wallpapers/the-whale.jpg;
      };
      "${config.home.homeDirectory}/.config/wallpapers/appa.jpg" = {
        source = ../../wallpapers/appa.jpg;
      };
      "${config.home.homeDirectory}/.config/wallpapers/.keep".text = "";
    };
  };
}
