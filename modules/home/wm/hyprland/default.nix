{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  cfg = config.wm.hyprland;

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

  fileManagerPkg = pkgs.cosmic-files;
in {
  imports = [
    inputs.cosmic-manager.homeManagerModules.default
    inputs.wayland-pipewire-idle-inhibit.homeModules.default
    ./animations.nix
    ./ironbar.nix # Customizable gtk-layer-shell wlroots/sway bar written in Rust
    ./keybinds.nix
    ./scratchpads.nix
    ./swaync.nix # Modern notification daemon
    ./themes.nix # Theme and appearance configuration
    ./walker.nix # Wayland-native application launcher
    ./workspaces.nix
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
      example = "cosmic-files";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [",preferred,auto,1"];
      description = "Monitor configuration";
      example = [
        "HDMI-A-1,1920x1080@60,0x0,1"
        "eDP-1,1920x1200@60,1920x0,1"
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
    home.packages = with pkgs; [
      # Home-specific utilities (not in system config)
      hyprsunset # Blue light filter
      hyprpolkitagent # Authentication agent
      swappy # Screenshot annotation
      wf-recorder # Screen recording
      cliphist # Clipboard history
      avizo # OSD for volume/brightness
      inputs.walker.packages.${pkgs.system}.default # Wayland-native application launcher with plugins
      inputs.self.packages.${pkgs.system}.vigiland # Wayland idle inhibitor
      udiskie # Auto-mount
      cosmic-files # File manager

      # Cursor themes (user-specific)
      adwaita-icon-theme # For Adwaita cursor theme
      bibata-cursors # Better cursor theme
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
      plugins = [
        inputs.hyprland-plugins.packages.${pkgs.system}.hyprexpo
      ];

      settings = {
        # Environment variables (home/user-specific only)
        env = [
          # Application defaults (user-configurable)
          "TERMINAL,${terminalPkg}/bin/${cfg.terminal}"
          "BROWSER,${browserPkg}/bin/${
            if cfg.browser == "zen"
            then "zen"
            else cfg.browser
          }"
          "FILEMANAGER,${fileManagerPkg}/bin/${cfg.fileManager}"

          # User-specific cursor configuration
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
          layout = "dwindle";
          allow_tearing = true;
        };

        # Decoration settings (themes are handled by themes.nix)
        decoration = {
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

        # Group configuration (colors handled by themes.nix)
        group = {
          # Group behavior settings only
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
        windowrulev2 = [
          # Scratchpad rules
          "float,class:^(scratchpad-.*)$"
          "size 80% 80%,class:^(scratchpad-.*)$"
          "center,class:^(scratchpad-.*)$"
          "opacity 0.95,class:^(scratchpad-.*)$"

          # Scratchpad help popup
          "float,class:^(scratchpad-help)$"
          "center,class:^(scratchpad-help)$"
          "size 600 400,class:^(scratchpad-help)$"
          "rounding 12,class:^(scratchpad-help)$"
          "opacity 0.95,class:^(scratchpad-help)$"
          "stayfocused,class:^(scratchpad-help)$"

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

          # Authentication and keyring dialogs - float on current workspace with priority focus
          "float,class:^(org.freedesktop.secrets)$"
          "float,class:^(gnome-keyring)$"
          "float,class:^(seahorse)$"
          "float,title:^(.*Authentication.*)"
          "float,title:^(.*Unlock.*)"
          "float,title:^(.*Password.*)"
          "center,class:^(org.freedesktop.secrets)$"
          "center,class:^(gnome-keyring)$"
          "center,title:^(.*Authentication.*)"
          "center,title:^(.*Unlock.*)"
          "center,title:^(.*Password.*)"
          "stayfocused,class:^(org.freedesktop.secrets)$"
          "stayfocused,title:^(.*Authentication.*)"
          "stayfocused,title:^(.*Unlock.*)"
          "stayfocused,title:^(.*Password.*)"
          "pin,title:^(.*Authentication.*)"
          "pin,title:^(.*Unlock.*)"
          "pin,title:^(.*Password.*)"
          "opaque,title:^(.*Authentication.*)"
          "opaque,title:^(.*Unlock.*)"
          "opaque,title:^(.*Password.*)"
          "immediate,title:^(.*Authentication.*)"
          "immediate,title:^(.*Unlock.*)"
          "immediate,title:^(.*Password.*)"

          # Picture-in-picture
          "float,title:^(Picture-in-Picture)$"
          "pin,title:^(Picture-in-Picture)$"
          "move 75% 75%,title:^(Picture-in-Picture)$"
          "size 24% 24%,title:^(Picture-in-Picture)$"

          # Bitwarden extension popup
          "float,title:^(Bitwarden)$"
          "float,title:^(.*Bitwarden.*)$"
          "center,title:^(Bitwarden)$"
          "center,title:^(.*Bitwarden.*)$"
          "stayfocused,title:^(Bitwarden)$"
          "stayfocused,title:^(.*Bitwarden.*)$"
          "pin,title:^(Bitwarden)$"
          "pin,title:^(.*Bitwarden.*)$"

          # Transparency
          "opacity 0.9,class:^(${cfg.terminal})$"
          "opacity 0.95,class:^(${cfg.fileManager})$"
          "opacity 0.95,class:^(zed)$"
        ];

        # Layer rules for better blur effects
        layerrule = [
          "blur,gtk-layer-shell"
          "blur,ironbar"
          "ignorezero,ironbar" # Prevents blur gaps when background-color is near 0 alpha
          "xray,ironbar" # Renders Ironbar over blur without darkening behind
          "blur,notifications"
          "blur,walker"
          "dimaround,walker"
          "blur,zed"
          "ignorezero,zed"
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
          "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
          # "${pkgs.networkmanagerapplet}/bin/nm-applet"
          "${pkgs.hyprland-autoname-workspaces}/bin/hyprland-autoname-workspaces"
        ];
      };
    };

    # Hyprsunset service for automatic sunset/sunrise blue light filtering
    systemd.user.services.hyprsunset = {
      Unit = {
        Description = "Hyprsunset Blue Light Filter";
        After = ["hyprland-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset -t 4500";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["hyprland-session.target"];
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
      "hypr/hyprpaper.conf".text = let
        wallpaperPath = config.lib.wallpapers.getCurrentWallpaperPath or "${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg";
      in ''
        # Preload wallpaper
        preload = ${wallpaperPath}

        # Set wallpaper for all monitors
        wallpaper = eDP-1,${wallpaperPath}
        wallpaper = ,${wallpaperPath}

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

      "hypr/hyprlock.conf".text = let
        wallpaperPath = config.lib.wallpapers.getCurrentWallpaperPath or "${config.home.homeDirectory}/.config/wallpapers/solar-system.jpg";
      in ''
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
            path = ${wallpaperPath}
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
    };

    # Wallpapers are now managed centrally by the wallpapers module
  };
}
