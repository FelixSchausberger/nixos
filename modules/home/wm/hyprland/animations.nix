{
  config,
  lib,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Enhanced animations with smooth bezier curves
      animations = {
        enabled = lib.mkDefault true; # Allow override by gaming module

        # Bezier curves for smooth animations
        bezier = [
          # Main bezier curves
          "wind, 0.05, 0.9, 0.1, 1.05"
          "winIn, 0.1, 1.1, 0.1, 1.1"
          "winOut, 0.3, -0.3, 0, 1"
          "liner, 1, 1, 1, 1"

          # Smooth easing curves
          "easeOutCubic, 0.33, 1, 0.68, 1"
          "easeInOutCubic, 0.65, 0, 0.35, 1"
          "easeOutExpo, 0.16, 1, 0.3, 1"
          "easeInOutBack, 0.68, -0.6, 0.32, 1.6"

          # Specialized curves
          "overshot, 0.05, 0.9, 0.1, 1.1"
          "smoothOut, 0.36, 0, 0.66, -0.56"
          "smoothIn, 0.25, 1, 0.5, 1"
        ];

        # Window animations
        animation = [
          # Windows
          "windows, 1, 6, easeOutCubic, slide"
          "windowsIn, 1, 6, easeOutCubic, slide"
          "windowsOut, 1, 5, easeInOutCubic, slide"
          "windowsMove, 1, 5, easeInOutCubic, slide"

          # Fading
          "fade, 1, 8, easeOutExpo"
          "fadeIn, 1, 8, easeOutExpo"
          "fadeOut, 1, 6, easeInOutCubic"
          "fadeDim, 1, 8, easeOutExpo"
          "fadeSwitch, 1, 8, easeOutExpo"
          "fadeShadow, 1, 8, easeOutExpo"
          "fadeLayersIn, 1, 8, easeOutExpo"
          "fadeLayersOut, 1, 6, easeInOutCubic"

          # Borders
          "border, 1, 12, easeOutExpo"
          "borderangle, 1, 12, easeOutExpo, once"

          # Workspaces
          "workspaces, 1, 7, easeOutCubic, slide"
          "specialWorkspace, 1, 6, easeInOutBack, slidevert"

          # Layers (for popups, notifications, etc.)
          "layers, 1, 6, easeOutExpo, slide"
          "layersIn, 1, 6, easeOutExpo, slide"
          "layersOut, 1, 5, easeInOutCubic, slide"
        ];
      };

      # Smooth transitions for various effects
      decoration = {
        # Smooth shadow transitions
        # shadow_offset = "0 8";

        # Enhanced blur for smooth performance
        blur = {
          enabled = lib.mkDefault true;
          size = 6;
          passes = 3;
          new_optimizations = true;

          # Smooth blur transitions
          ignore_opacity = true;
          noise = 0.1;
          contrast = 1.1;
          brightness = 1.2;

          # Blur special surfaces
          special = true;
          popups = true;
          popups_ignorealpha = 0.6;
        };

        # Smooth rounding
        rounding = lib.mkDefault 12;

        # Enhanced drop shadow
        # drop_shadow = true;
        # shadow_range = 20;
        # shadow_render_power = 3;
        # shadow_ignore_window = true;
        # "col.shadow" = "rgba(1e1e2eee)";
        # shadow_scale = 1.0;
      };

      # Smooth input handling
      input = {
        # Reduce input lag
        follow_mouse = lib.mkDefault 1;
        mouse_refocus = lib.mkDefault false;

        # Smooth touchpad
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
          middle_button_emulation = true;
          clickfinger_behavior = true;
          scroll_factor = 0.3;
          drag_lock = false;
        };

        # Smooth mouse
        sensitivity = 0;
        accel_profile = "flat";
        force_no_accel = true;
      };

      # Optimized rendering for smooth animations
      misc = {
        # VRR (Variable Refresh Rate) for smooth animations
        vrr = 2;

        # Animation optimizations
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        disable_autoreload = false;

        # Performance optimizations
        focus_on_activate = true;
        # no_direct_scanout = false;

        # Smooth mouse movement
        mouse_move_focuses_monitor = lib.mkDefault true;
        always_follow_on_dnd = lib.mkDefault true;

        # Background optimizations
        background_color = lib.mkDefault "0x1e1e2e";

        # Swallow animations
        enable_swallow = true;
        swallow_exception_regex = "^(wev|Wayland-testbench)$";

        # Layer animations
        layers_hog_keyboard_focus = true;

        # Render optimizations
        # render_ahead_of_time = false;
        # render_ahead_safezone = 1;

        # Close animation delay
        close_special_on_empty = true;
        new_window_takes_over_fullscreen = 2;
      };

      # Smooth group animations
      group = {
        insert_after_current = true;
        focus_removed_window = true;

        groupbar = {
          enabled = true;
          font_family = "JetBrainsMono Nerd Font";
          font_size = 10;
          gradients = true;
          height = 14;
          priority = 3;
          render_titles = true;
          scrolling = true;
          text_color = "rgb(cdd6f4)";

          # Smooth groupbar colors
          "col.active" = "rgb(89b4fa)";
          "col.inactive" = "rgb(45475a)";
          "col.locked_active" = "rgb(f38ba8)";
          "col.locked_inactive" = "rgb(585b70)";
        };
      };

      # Smooth binds for better animation feel
      binds = {
        allow_workspace_cycles = true;
        workspace_back_and_forth = true;
        focus_preferred_method = 0;
        ignore_group_lock = false;
        movefocus_cycles_fullscreen = true;
        disable_keybind_grabbing = false;
        window_direction_monitor_fallback = true;
        workspace_center_on = 1;
      };

      # Cursor animations
      cursor = {
        no_hardware_cursors = lib.mkDefault false; # Allow override for AMD 680M
        no_break_fs_vrr = false;
        min_refresh_rate = 24;
        hotspot_padding = 0;
        inactive_timeout = 0;
        no_warps = false;
        persistent_warps = false;
        warp_on_change_workspace = false;
        default_monitor = lib.mkDefault "";
        zoom_factor = 1.0;
        zoom_rigid = false;
        enable_hyprcursor = lib.mkDefault true;
        hide_on_key_press = lib.mkDefault false;
        hide_on_touch = true;
      };

      # Debug options for animation tuning (disable in production)
      debug = {
        #   overlay = false;
        #   damage_blink = false;
        disable_logs = false;
        #   disable_time = true;
        #   damage_tracking = 2;
        #   enable_stdout_logs = false;
        #   manual_crash = 0;
        #   suppress_errors = false;
        #   error_limit = 5;
        #   error_position = 0;
        #   colored_stdout_logs = true;
      };
    };
  };
}
