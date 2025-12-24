{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  cfg = config.wm.niri;
  safeNotifySend = import ../../../../home/lib/safe-notify-send.nix {inherit pkgs config lib;};
  safeNotifyBin = "${safeNotifySend}/bin/safe-notify-send";

  # Package mappings for applications
  browserPkg =
    if cfg.browser == "zen"
    then inputs.zen-browser.packages.${pkgs.hostPlatform.system}.default
    else if cfg.browser == "firefox"
    then pkgs.firefox
    else if cfg.browser == "chromium"
    then pkgs.chromium
    else pkgs.firefox;

  terminalPkg =
    if cfg.terminal == "ghostty"
    then inputs.ghostty.packages.${pkgs.hostPlatform.system}.default
    else if cfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if cfg.terminal == "wezterm"
    then pkgs.wezterm
    else inputs.ghostty.packages.${pkgs.hostPlatform.system}.default;

  fileManagerPkg = pkgs.cosmic-files;
in {
  imports = [
    inputs.cosmic-manager.homeManagerModules.default
    inputs.wayland-pipewire-idle-inhibit.homeModules.default
    ./walker.nix
    ./ironbar.nix
    # Shared options and imports (imported once)
    ../shared-imports.nix # Shared homeManager module imports
    ../shared/options.nix
    ../shared/wayland-pipewire-idle-inhibit.nix
    ../shared/satty.nix
    ../shared/vigiland-simple.nix
    (import ../shared/wpaperd.nix "niri-session.target") # Wallpaper daemon
    (import ../shared/wired.nix "niri-session.target") # Modern notification daemon configuration
    (import ../shared/cthulock.nix "niri-session.target") # Screen locker
  ];

  options.wm.niri = {
    enable = lib.mkEnableOption "Niri window manager";

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

    outputs = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Output name";
          };
          mode = lib.mkOption {
            type = lib.types.submodule {
              options = {
                width = lib.mkOption {
                  type = lib.types.int;
                  description = "Output width in pixels";
                };
                height = lib.mkOption {
                  type = lib.types.int;
                  description = "Output height in pixels";
                };
                refresh = lib.mkOption {
                  type = lib.types.float;
                  description = "Refresh rate in Hz";
                  default = 60.0;
                };
              };
            };
            default = {};
          };
          scale = lib.mkOption {
            type = lib.types.float;
            default = 1.0;
            description = "Output scale factor";
          };
          transform = lib.mkOption {
            type = lib.types.enum ["normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270"];
            default = "normal";
            description = "Output transform";
          };
          position = lib.mkOption {
            type = lib.types.submodule {
              options = {
                x = lib.mkOption {
                  type = lib.types.int;
                  description = "X position";
                  default = 0;
                };
                y = lib.mkOption {
                  type = lib.types.int;
                  description = "Y position";
                  default = 0;
                };
              };
            };
            default = {};
          };
        };
      });
      default = [];
      description = "Output configuration";
      example = [
        {
          name = "DP-1";
          mode = {
            width = 2560;
            height = 1440;
            refresh = 144.0;
          };
          scale = 1.0;
          position = {
            x = 0;
            y = 0;
          };
        }
      ];
    };

    # scratchpad = {
    #   notesApp = lib.mkOption {
    #     type = lib.types.enum ["obsidian" "basalt"];
    #     default = "obsidian";
    #     description = "Notes application for scratchpad";
    #   };

    #   musicApp = lib.mkOption {
    #     type = lib.types.enum ["spotify" "spotify-player"];
    #     default = "spotify";
    #     description = "Music application for scratchpad";
    #   };
    # };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        # Niri-specific utilities
        swappy # Screenshot annotation
        cliphist # Clipboard history
        avizo # OSD for volume/brightness
        udiskie # Auto-mount
        cosmic-files # File manager
        # Cursor themes
        adwaita-icon-theme # For Adwaita cursor theme
        bibata-cursors # Better cursor theme
        gnome-themes-extra # Additional cursor themes
        hicolor-icon-theme # Base icon theme
      ];

      # Home environment variables for proper cursor theme support
      sessionVariables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
      };
    };

    # Niri declarative configuration using programs.niri.settings
    # Provided by niri-flake's home-manager module (auto-imported via nixosModules.niri)
    programs.niri.settings = {
      # Input configuration
      input = {
        keyboard.xkb = {
          layout = "eu,de";
          variant = ",";
          options = "grp:alt_shift_toggle,terminate:ctrl_alt_bksp";
          model = "pc104";
        };

        touchpad = {
          tap = true;
          dwt = true;
          natural-scroll = true;
        };

        mouse = {
          accel-speed = 0.0;
          accel-profile = "adaptive";
        };

        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "0%";
        };

        workspace-auto-back-and-forth = true;
      };

      # Layout configuration
      layout = {
        gaps = 16;
        center-focused-column = "never";
        default-column-width = {proportion = 0.5;};

        preset-column-widths = [
          {proportion = 0.33333;}
          {proportion = 0.5;}
          {proportion = 0.66667;}
        ];

        preset-window-heights = [
          {proportion = 0.33333;}
          {proportion = 0.5;}
          {proportion = 0.66667;}
        ];

        # Border width only - colors managed by Stylix integration
        border = {
          enable = true;
          width = 2;
        };
      };

      prefer-no-csd = true; # omit client-side decorations

      # Hotkey overlay configuration
      hotkey-overlay.skip-at-startup = true;

      # Debug configuration for honoring XDG activation requests with invalid serial
      # TODO: Cannot be set via programs.niri.settings due to KDL generation issue
      # Add manually to ~/.config/niri/config.kdl if needed:
      # debug { honor-xdg-activation-with-invalid-serial; }

      # Environment variables
      environment = {
        TERMINAL = "${terminalPkg}/bin/${cfg.terminal}";
        BROWSER = "${browserPkg}/bin/${cfg.browser}";
        #   if cfg.browser == "zen"
        #   then "zen"
        #   else cfg.browser
        # }";
        FILEMANAGER = "${fileManagerPkg}/bin/${cfg.fileManager}";
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
      };

      # Startup applications
      spawn-at-startup = [
        {command = ["${pkgs.avizo}/bin/avizo-service"];}
        {command = ["${inputs.ironbar.packages.${pkgs.hostPlatform.system}.default}/bin/ironbar"];}
        {command = ["${pkgs.udiskie}/bin/udiskie" "--tray"];}
        {command = ["${pkgs.wl-clipboard}/bin/wl-paste" "--type" "text" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"];}
        {command = ["${pkgs.wl-clipboard}/bin/wl-paste" "--type" "image" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"];}
      ];

      # Cursor configuration
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
      };

      # Window rules
      # window-rules = [
      #   {
      #     matches = [{app-id = "^scratchpad-.*";}];
      #     default-column-width = {proportion = 0.8;};
      #     open-on-output = "eDP-1";
      #   }
      #   {
      #     matches = [{app-id = "^${cfg.browser}$";}];
      #     open-on-workspace = "Browser";
      #   }
      #   {
      #     matches = [{app-id = "^(code-url-handler|Code)$";}];
      #     open-on-workspace = "Code";
      #   }
      #   {
      #     matches = [{app-id = "^pavucontrol$";}];
      #     default-column-width = {fixed = 400;};
      #     open-on-output = "focused";
      #   }
      #   {
      #     matches = [{app-id = "^it\\.mijorus\\.smile$";}];
      #     default-column-width = {fixed = 400;};
      #     open-on-output = "focused";
      #   }
      #   {
      #     matches = [{app-id = "^org\\.gnome\\.Calculator$";}];
      #     default-column-width = {fixed = 400;};
      #     open-on-output = "focused";
      #   }
      #   {
      #     matches = [{app-id = "^nm-connection-editor$";}];
      #     default-column-width = {fixed = 400;};
      #     open-on-output = "focused";
      #   }
      #   {
      #     matches = [{title = "^Picture-in-Picture$";}];
      #     default-column-width = {fixed = 480;};
      #     open-on-output = "focused";
      #   }
      # ];

      # Named workspaces
      # workspaces = {
      #   "Terminal" = {};
      #   "Browser" = {};
      #   "Code" = {};
      #   "Chat" = {};
      #   "Music" = {};
      #   "Games" = {};
      # };

      # Default niri keybindings (based on niri's default-config.kdl)
      binds = with config.lib.niri.actions; {
        # Application shortcuts
        "Mod+T".action = spawn "${terminalPkg}/bin/${cfg.terminal}";
        "Mod+D".action = spawn "walker";

        # Window management
        "Mod+Q".action = close-window;
        "Mod+V".action = toggle-window-floating;
        "Mod+Shift+V".action = switch-focus-between-floating-and-tiling;
        "Mod+W".action = toggle-tabbed-column-display;

        # Fullscreen and maximize
        "Mod+F".action = maximize-column;
        "Mod+Shift+F".action = fullscreen-window;
        "Mod+Ctrl+F".action = maximize-window-to-edges;

        # Center column
        "Mod+C".action = center-column;
        "Mod+Ctrl+C".action = center-visible-columns;

        # Column width and window height
        "Mod+R".action = switch-preset-column-width;
        "Mod+Shift+R".action = switch-preset-window-height;
        "Mod+Ctrl+R".action = reset-window-height;
        "Mod+Minus".action = set-column-width "-10%";
        "Mod+Equal".action = set-column-width "+10%";
        "Mod+Shift+Minus".action = set-window-height "-10%";
        "Mod+Shift+Equal".action = set-window-height "+10%";

        # Column width and window height (Colemak-DH)
        "Mod+Alt+N".action = set-column-width "-10%";
        "Mod+Alt+O".action = set-column-width "+10%";
        "Mod+Alt+E".action = set-window-height "-10%";
        "Mod+Alt+I".action = set-window-height "+10%";

        # Window focus (vim keys)
        "Mod+H".action = focus-column-left;
        "Mod+J".action = focus-window-down;
        "Mod+K".action = focus-window-up;
        "Mod+L".action = focus-column-right;

        # Window focus (Colemak-DH)
        "Mod+N".action = focus-column-left;
        "Mod+E".action = focus-window-down;
        "Mod+I".action = focus-window-up;
        "Mod+O".action = focus-column-right;

        # Window focus (arrow keys)
        "Mod+Left".action = focus-column-left;
        "Mod+Down".action = focus-window-down;
        "Mod+Up".action = focus-window-up;
        "Mod+Right".action = focus-column-right;

        # Focus first/last column
        "Mod+Home".action = focus-column-first;
        "Mod+End".action = focus-column-last;

        # Window movement (vim keys)
        "Mod+Ctrl+H".action = move-column-left;
        "Mod+Ctrl+J".action = move-window-down;
        "Mod+Ctrl+K".action = move-window-up;
        "Mod+Ctrl+L".action = move-column-right;

        # Window movement (Colemak-DH)
        "Mod+Ctrl+N".action = move-column-left;
        "Mod+Ctrl+E".action = move-window-down;
        "Mod+Ctrl+I".action = move-window-up;
        "Mod+Ctrl+O".action = move-column-right;

        # Window movement (arrow keys)
        "Mod+Ctrl+Left".action = move-column-left;
        "Mod+Ctrl+Down".action = move-window-down;
        "Mod+Ctrl+Up".action = move-window-up;
        "Mod+Ctrl+Right".action = move-column-right;

        # Move to first/last column
        "Mod+Ctrl+Home".action = move-column-to-first;
        "Mod+Ctrl+End".action = move-column-to-last;

        # Monitor focus (vim keys)
        "Mod+Shift+H".action = focus-monitor-left;
        "Mod+Shift+J".action = focus-monitor-down;
        "Mod+Shift+K".action = focus-monitor-up;
        "Mod+Shift+L".action = focus-monitor-right;

        # Monitor focus (Colemak-DH)
        "Mod+Shift+N".action = focus-monitor-left;
        "Mod+Shift+E".action = focus-monitor-down;
        "Mod+Shift+I".action = focus-monitor-up;
        "Mod+Shift+O".action = focus-monitor-right;

        # Monitor focus (arrow keys)
        "Mod+Shift+Left".action = focus-monitor-left;
        "Mod+Shift+Down".action = focus-monitor-down;
        "Mod+Shift+Up".action = focus-monitor-up;
        "Mod+Shift+Right".action = focus-monitor-right;

        # Move to monitor (vim keys)
        "Mod+Shift+Ctrl+H".action = move-column-to-monitor-left;
        "Mod+Shift+Ctrl+J".action = move-column-to-monitor-down;
        "Mod+Shift+Ctrl+K".action = move-column-to-monitor-up;
        "Mod+Shift+Ctrl+L".action = move-column-to-monitor-right;

        # Move to monitor (Colemak-DH)
        "Mod+Shift+Ctrl+N".action = move-column-to-monitor-left;
        "Mod+Shift+Ctrl+E".action = move-column-to-monitor-down;
        "Mod+Shift+Ctrl+I".action = move-column-to-monitor-up;
        "Mod+Shift+Ctrl+O".action = move-column-to-monitor-right;

        # Move to monitor (arrow keys)
        "Mod+Shift+Ctrl+Left".action = move-column-to-monitor-left;
        "Mod+Shift+Ctrl+Down".action = move-column-to-monitor-down;
        "Mod+Shift+Ctrl+Up".action = move-column-to-monitor-up;
        "Mod+Shift+Ctrl+Right".action = move-column-to-monitor-right;

        # Workspace navigation
        "Mod+Page_Down".action = focus-workspace-down;
        "Mod+Page_Up".action = focus-workspace-up;

        # Workspace navigation (numeric)
        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;

        # Move window to workspace
        "Mod+Ctrl+Page_Down".action = move-column-to-workspace-down;
        "Mod+Ctrl+Page_Up".action = move-column-to-workspace-up;

        # Move window to workspace (numeric)
        "Mod+Ctrl+1".action.move-column-to-workspace = 1;
        "Mod+Ctrl+2".action.move-column-to-workspace = 2;
        "Mod+Ctrl+3".action.move-column-to-workspace = 3;
        "Mod+Ctrl+4".action.move-column-to-workspace = 4;
        "Mod+Ctrl+5".action.move-column-to-workspace = 5;
        "Mod+Ctrl+6".action.move-column-to-workspace = 6;
        "Mod+Ctrl+7".action.move-column-to-workspace = 7;
        "Mod+Ctrl+8".action.move-column-to-workspace = 8;
        "Mod+Ctrl+9".action.move-column-to-workspace = 9;

        # Move workspace
        "Mod+Shift+Page_Down".action = move-workspace-down;
        "Mod+Shift+Page_Up".action = move-workspace-up;

        # Consume and expel windows
        "Mod+BracketLeft".action = consume-or-expel-window-left;
        "Mod+BracketRight".action = consume-or-expel-window-right;
        "Mod+Comma".action = consume-window-into-column;
        "Mod+Period".action = expel-window-from-column;

        # Screenshots
        "Print".action.screenshot = {};
        "Ctrl+Print".action.screenshot-screen = {};
        "Alt+Print".action.screenshot-window = {};

        # System
        "Mod+Shift+Slash".action = show-hotkey-overlay;
        "Mod+Escape".action = toggle-debug-tint;
        "Mod+Shift+Q".action = quit;
        "Ctrl+Alt+Delete".action = quit;
        "Mod+Shift+P".action = power-off-monitors;

        # Custom: Lock screen
        "Super+Alt+L".action = spawn "loginctl" "lock-session";
      };
    };

    # Enable xwayland-satellite for X11 app compatibility
    systemd.user.services.xwayland-satellite = {
      Unit = {
        Description = "Xwayland outside your Wayland";
        BindsTo = ["niri-session.target"];
        After = ["niri-session.target"];
      };

      Service = {
        Type = "notify";
        NotifyAccess = "all";
        ExecStart = "${inputs.niri.packages.${pkgs.hostPlatform.system}.xwayland-satellite-unstable}/bin/xwayland-satellite";
        StandardOutput = "journal";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = ["niri-session.target"];
      };
    };
  };
}
