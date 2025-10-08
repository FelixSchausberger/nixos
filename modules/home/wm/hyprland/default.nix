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
    ./walker.nix # Wayland-native application launcher
    ./workspaces.nix
    # Shared options (imported once)
    ../shared/options.nix
    ../shared/wayland-pipewire-idle-inhibit.nix
    # Use shared compositor-agnostic modules with hyprland session target
    (import ../shared/wired.nix "hyprland-session.target") # Modern notification daemon
    # (import ../shared/cthulock.nix "hyprland-session.target") # Screen locker - disabled until package is fixed
    (import ../shared/wl-gammarelay.nix "hyprland-session.target") # Gamma control
    (import ../shared/wpaperd.nix "hyprland-session.target") # Wallpaper daemon
    ../shared/satty.nix # Screenshot tool
    ../shared/vigiland-simple.nix # Wayland idle inhibitor
    # (import ../shared/ala-lape.nix "hyprland-session.target") # Idle inhibitor - disabled until package is fixed
    # (import ../shared/wlsleephandler-rs.nix "hyprland-session.target") # Sleep handler - disabled until package is fixed
    (import ../shared/themes.nix "hyprland-session.target") # Theme and appearance configuration
    (import ../shared/wallpaper.nix "hyprland-session.target") # Wallpaper management
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
      # Home-specific utilities
      hyprpolkitagent # Authentication agent
      swappy # Screenshot annotation
      cliphist # Clipboard history
      avizo # OSD for volume/brightness
      inputs.walker.packages.${pkgs.system}.default # Wayland-native application launcher with plugins
      udiskie # Auto-mount
      cosmic-files # File manager
      # Cursor themes
      adwaita-icon-theme # For Adwaita cursor theme
      bibata-cursors # Better cursor theme

      # Screenshot tools provided by shared/satty.nix
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
          layout = "dwindle";
          allow_tearing = true;
        };

        # Decoration settings
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

        # Gesture configuration (replaces deprecated workspace_swipe options)
        # gestures = {
        #   workspace_swipe = true;
        #   workspace_swipe_fingers = 3;
        #   workspace_swipe_distance = 300;
        #   workspace_swipe_invert = true;
        #   workspace_swipe_min_speed_to_force = 30;
        #   workspace_swipe_cancel_ratio = 0.5;
        #   workspace_swipe_create_new = false;
        # };

        render = {
          direct_scanout = lib.mkDefault true;
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
          "${inputs.ironbar.packages.${pkgs.system}.default}/bin/ironbar"
          "${pkgs.udiskie}/bin/udiskie --tray"
          "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store"
          "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store"
          "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
        ];
      };
    };
  };
}
