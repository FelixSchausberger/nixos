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
    # (import ../shared/cthulock.nix "niri-session.target") # Screen locker - disabled until package is fixed
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
    home = {
      packages = with pkgs; [
        # Niri-specific utilities
        swappy # Screenshot annotation
        cliphist # Clipboard history
        avizo # OSD for volume/brightness
        inputs.walker.packages.${pkgs.hostPlatform.system}.default # Wayland-native application launcher with plugins
        udiskie # Auto-mount
        cosmic-files # File manager
        # Cursor themes
        adwaita-icon-theme # For Adwaita cursor theme
        bibata-cursors # Better cursor theme
        gnome-themes-extra # Additional cursor themes
        hicolor-icon-theme # Base icon theme

        # Screenshot tools provided by shared/satty.nix
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

      prefer-no-csd = true;

      # Hotkey overlay configuration
      hotkey-overlay.skip-at-startup = true;

      # Debug configuration for honoring XDG activation requests with invalid serial
      # TODO: Cannot be set via programs.niri.settings due to KDL generation issue
      # Add manually to ~/.config/niri/config.kdl if needed:
      # debug { honor-xdg-activation-with-invalid-serial; }

      # Environment variables
      environment = {
        TERMINAL = "${terminalPkg}/bin/${cfg.terminal}";
        BROWSER = "${browserPkg}/bin/${
          if cfg.browser == "zen"
          then "zen"
          else cfg.browser
        }";
        FILEMANAGER = "${fileManagerPkg}/bin/${cfg.fileManager}";
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
      };

      # Startup applications
      # spawn-at-startup = [
      # {command = ["${pkgs.avizo}/bin/avizo-service"];}
      # {command = ["${inputs.ironbar.packages.${pkgs.hostPlatform.system}.default}/bin/ironbar"];}
      # {command = ["${pkgs.udiskie}/bin/udiskie" "--tray"];}
      # {command = ["${pkgs.wl-clipboard}/bin/wl-paste" "--type" "text" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"];}
      # {command = ["${pkgs.wl-clipboard}/bin/wl-paste" "--type" "image" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"];}
      # ];

      # Cursor configuration
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
      };

      # Window rules
      window-rules = [
        {
          matches = [{app-id = "^scratchpad-.*";}];
          default-column-width = {proportion = 0.8;};
          open-on-output = "eDP-1";
        }
        {
          matches = [{app-id = "^${cfg.browser}$";}];
          open-on-workspace = "Browser";
        }
        {
          matches = [{app-id = "^(code-url-handler|Code)$";}];
          open-on-workspace = "Code";
        }
        {
          matches = [{app-id = "^pavucontrol$";}];
          default-column-width = {fixed = 400;};
          open-on-output = "focused";
        }
        {
          matches = [{app-id = "^it\\.mijorus\\.smile$";}];
          default-column-width = {fixed = 400;};
          open-on-output = "focused";
        }
        {
          matches = [{app-id = "^org\\.gnome\\.Calculator$";}];
          default-column-width = {fixed = 400;};
          open-on-output = "focused";
        }
        {
          matches = [{app-id = "^nm-connection-editor$";}];
          default-column-width = {fixed = 400;};
          open-on-output = "focused";
        }
        {
          matches = [{title = "^Picture-in-Picture$";}];
          default-column-width = {fixed = 480;};
          open-on-output = "focused";
        }
      ];

      # Named workspaces
      workspaces = {
        "Terminal" = {};
        "Browser" = {};
        "Code" = {};
        "Chat" = {};
        "Music" = {};
        "Games" = {};
      };

      # Keybindings using helper functions from config.lib.niri.actions
      binds = with config.lib.niri.actions; {
        # Application shortcuts
        "Mod+T".action = spawn "${terminalPkg}/bin/${cfg.terminal}";
        "Mod+D".action = spawn "${inputs.walker.packages.${pkgs.hostPlatform.system}.default}/bin/walker";
        "Mod+Return".action = spawn "${browserPkg}/bin/${
          if cfg.browser == "zen"
          then "zen"
          else cfg.browser
        }";
        "Mod+Q".action = close-window;
        "Mod+L".action = spawn "loginctl" "lock-session";

        # Hotkey overlay
        "Mod+Shift+Slash".action = show-hotkey-overlay;

        # Notifications
        "Mod+Escape".action = spawn "${safeNotifyBin}" "Test" "Wired notification system";
        "Mod+Shift+Escape".action = spawn "pkill" "-SIGUSR1" "wired";

        # Window management
        "Mod+Space".action = toggle-window-floating;
        "Mod+F".action = fullscreen-window;
        "Mod+C".action = center-column;
        "Mod+R".action = switch-preset-column-width;
        "Mod+Shift+R".action = switch-preset-window-height;

        # Window focus (Colemak-DH N/E/I/O pattern)
        "Mod+N".action = focus-column-left;
        "Mod+Left".action = focus-column-left;
        "Mod+E".action = focus-window-down;
        "Mod+Down".action = focus-window-down;
        "Mod+I".action = focus-window-up;
        "Mod+Up".action = focus-window-up;
        "Mod+O".action = focus-column-right;
        "Mod+Right".action = focus-column-right;

        # Window movement
        "Mod+Ctrl+N".action = move-column-left;
        "Mod+Ctrl+Left".action = move-column-left;
        "Mod+Ctrl+E".action = move-window-down;
        "Mod+Ctrl+Down".action = move-window-down;
        "Mod+Ctrl+I".action = move-window-up;
        "Mod+Ctrl+Up".action = move-window-up;
        "Mod+Ctrl+O".action = move-column-right;
        "Mod+Ctrl+Right".action = move-column-right;

        # Monitor focus
        "Mod+Shift+N".action = focus-monitor-left;
        "Mod+Shift+Left".action = focus-monitor-left;
        "Mod+Shift+E".action = focus-monitor-down;
        "Mod+Shift+Down".action = focus-monitor-down;
        "Mod+Shift+I".action = focus-monitor-up;
        "Mod+Shift+Up".action = focus-monitor-up;
        "Mod+Shift+O".action = focus-monitor-right;
        "Mod+Shift+Right".action = focus-monitor-right;

        # Move to monitor
        "Mod+Ctrl+Shift+N".action = move-column-to-monitor-left;
        "Mod+Ctrl+Shift+Left".action = move-column-to-monitor-left;
        "Mod+Ctrl+Shift+E".action = move-column-to-monitor-down;
        "Mod+Ctrl+Shift+Down".action = move-column-to-monitor-down;
        "Mod+Ctrl+Shift+I".action = move-column-to-monitor-up;
        "Mod+Ctrl+Shift+Up".action = move-column-to-monitor-up;
        "Mod+Ctrl+Shift+O".action = move-column-to-monitor-right;
        "Mod+Ctrl+Shift+Right".action = move-column-to-monitor-right;

        # Window resizing
        "Mod+Alt+N".action = set-column-width "-10%";
        "Mod+Alt+O".action = set-column-width "+10%";
        "Mod+Alt+E".action = set-window-height "-10%";
        "Mod+Alt+I".action = set-window-height "+10%";

        # Consume and expel
        "Mod+Comma".action = consume-window-into-column;
        "Mod+Period".action = expel-window-from-column;
        "Mod+BracketLeft".action = consume-or-expel-window-left;
        "Mod+BracketRight".action = consume-or-expel-window-right;

        # Workspace navigation
        "Mod+U".action = focus-workspace-down;
        "Mod+Page_Down".action = focus-workspace-down;
        "Mod+Shift+U".action = move-workspace-down;
        "Mod+Shift+Page_Down".action = move-workspace-down;
        "Mod+Ctrl+U".action = move-column-to-workspace-down;
        "Mod+Ctrl+Page_Down".action = move-column-to-workspace-down;

        # Named workspaces
        "Mod+1".action.focus-workspace = "Terminal";
        "Mod+2".action.focus-workspace = "Browser";
        "Mod+3".action.focus-workspace = "Code";
        "Mod+4".action.focus-workspace = "Chat";
        "Mod+5".action.focus-workspace = "Music";
        "Mod+6".action.focus-workspace = "Games";

        # Move windows to workspaces
        "Mod+Shift+1".action.move-column-to-workspace = "Terminal";
        "Mod+Shift+2".action.move-column-to-workspace = "Browser";
        "Mod+Shift+3".action.move-column-to-workspace = "Code";
        "Mod+Shift+4".action.move-column-to-workspace = "Chat";
        "Mod+Shift+5".action.move-column-to-workspace = "Music";
        "Mod+Shift+6".action.move-column-to-workspace = "Games";

        # System controls
        "Mod+V".action = spawn "${pkgs.avizo}/bin/volumectl" "toggle-mute";
        "Mod+Equal".action = spawn "${pkgs.avizo}/bin/volumectl" "up";
        "Mod+Minus".action = spawn "${pkgs.avizo}/bin/volumectl" "down";
        "Mod+Shift+Equal".action = spawn "${pkgs.avizo}/bin/lightctl" "up";
        "Mod+Shift+Minus".action = spawn "${pkgs.avizo}/bin/lightctl" "down";

        # Screenshots
        "Print".action = spawn "screenshot-region";
        "Shift+Print".action = spawn "screenshot-full";
        "Mod+Print".action = spawn "screenshot-region";

        # Idle inhibitor
        "Mod+Z".action = spawn "sh" "-c" "pkill -x vigiland || vigiland &";

        "Mod+Shift+Q".action = quit;
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
