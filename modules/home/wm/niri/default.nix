{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  cfg = config.wm.niri;

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
    ./walker.nix
    ./ironbar.nix
    # Shared options (imported once)
    ../shared/options.nix
    ../shared/wayland-pipewire-idle-inhibit.nix
    ../shared/satty.nix
    ../shared/vigiland-simple.nix
  ];

  options.wm.niri = {
    enable = lib.mkEnableOption "Niri window manager" // {default = true;};

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
        inputs.walker.packages.${pkgs.system}.default # Wayland-native application launcher with plugins
        udiskie # Auto-mount
        cosmic-files # File manager
        # Cursor themes
        adwaita-icon-theme # For Adwaita cursor theme
        bibata-cursors # Better cursor theme
        gnome-themes-extra # Additional cursor themes
        hicolor-icon-theme # Base icon theme

        # Screenshot tools provided by shared/satty.nix
      ];

      # Niri configuration through config file since system module handles program
      file.".config/niri/config.kdl".text = ''
        input {
            keyboard {
                xkb {
                    layout "eu,de"
                    variant ","
                    options "grp:alt_shift_toggle,terminate:ctrl_alt_bksp"
                    model "pc104"
                }
            }

            touchpad {
                tap
                dwt
                natural-scroll
            }

            mouse {
                accel-speed 0.0
                accel-profile "adaptive"
            }

            focus-follows-mouse max-scroll-amount="0%"
            workspace-auto-back-and-forth
        }

        layout {
            gaps 16
            center-focused-column "never"
            default-column-width { proportion 0.5; }

            preset-column-widths {
                proportion 0.33333
                proportion 0.5
                proportion 0.66667
            }

            preset-window-heights {
                proportion 0.33333
                proportion 0.5
                proportion 0.66667
            }

            border {
                width 2
                active-color "#ffc87f"
                inactive-color "#505050"
            }
        }

        prefer-no-csd


        hotkey-overlay {
            skip-at-startup
        }

        environment {
            TERMINAL "${terminalPkg}/bin/${cfg.terminal}"
            BROWSER "${browserPkg}/bin/${
          if cfg.browser == "zen"
          then "zen"
          else cfg.browser
        }"
            FILEMANAGER "${fileManagerPkg}/bin/${cfg.fileManager}"
            XCURSOR_THEME "Bibata-Modern-Classic"
            XCURSOR_SIZE "24"
        }

        spawn-at-startup {
            command "${pkgs.avizo}/bin/avizo-service"
        }
        spawn-at-startup {
            command "${inputs.ironbar.packages.${pkgs.system}.default}/bin/ironbar"
        }
        spawn-at-startup {
            command "${pkgs.udiskie}/bin/udiskie" "--tray"
        }
        spawn-at-startup {
            command "${pkgs.wl-clipboard}/bin/wl-paste" "--type" "text" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"
        }
        spawn-at-startup {
            command "${pkgs.wl-clipboard}/bin/wl-paste" "--type" "image" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"
        }

        cursor {
            theme "Bibata-Modern-Classic"
            size 24
        }

        window-rule {
            match app-id="^scratchpad-.*"
            default-column-width { proportion 0.8; }
            open-on-output "eDP-1"
        }

        window-rule {
            match app-id="^${cfg.browser}$"
            open-on-workspace "Browser"
        }

        window-rule {
            match app-id="^(code-url-handler|Code)$"
            open-on-workspace "Code"
        }

        window-rule {
            match app-id="^pavucontrol$"
            default-column-width { fixed 400; }
            open-on-output "focused"
        }

        window-rule {
            match app-id="^it\.mijorus\.smile$"
            default-column-width { fixed 400; }
            open-on-output "focused"
        }

        window-rule {
            match app-id="^org\.gnome\.Calculator$"
            default-column-width { fixed 400; }
            open-on-output "focused"
        }

        window-rule {
            match app-id="^nm-connection-editor$"
            default-column-width { fixed 400; }
            open-on-output "focused"
        }

        window-rule {
            match title="^Picture-in-Picture$"
            default-column-width { fixed 480; }
            open-on-output "focused"
        }

        workspace "Terminal"
        workspace "Browser"
        workspace "Code"
        workspace "Chat"
        workspace "Music"
        workspace "Games"

        binds {
            // Application shortcuts
            "Mod+T" { spawn "${terminalPkg}/bin/${cfg.terminal}"; }
            "Mod+D" { spawn "${inputs.walker.packages.${pkgs.system}.default}/bin/walker"; }
            "Mod+Return" { spawn "${browserPkg}/bin/${
          if cfg.browser == "zen"
          then "zen"
          else cfg.browser
        }"; }
            "Mod+Q" { close-window; }
            "Super+Alt+L" { spawn "${pkgs.swaylock}/bin/swaylock"; }

            // Hotkey overlay
            "Mod+Shift+Slash" { show-hotkey-overlay; }

            // Window management
            "Mod+Space" { toggle-window-floating; }
            "Mod+F" { fullscreen-window; }
            "Mod+C" { center-column; }
            "Mod+R" { switch-preset-column-width; }
            "Mod+Shift+R" { switch-preset-window-height; }

            // Window focus (Colemak-DH N/E/I/O pattern)
            "Mod+N" { focus-column-left; }
            "Mod+Left" { focus-column-left; }
            "Mod+E" { focus-window-down; }
            "Mod+Down" { focus-window-down; }
            "Mod+I" { focus-window-up; }
            "Mod+Up" { focus-window-up; }
            "Mod+O" { focus-column-right; }
            "Mod+Right" { focus-column-right; }

            // Window movement (Shift + N/E/I/O)
            "Mod+Ctrl+N" { move-column-left; }
            "Mod+Ctrl+Left" { move-column-left; }
            "Mod+Ctrl+E" { move-window-down; }
            "Mod+Ctrl+Down" { move-window-down; }
            "Mod+Ctrl+I" { move-window-up; }
            "Mod+Ctrl+Up" { move-window-up; }
            "Mod+Ctrl+O" { move-column-right; }
            "Mod+Ctrl+Right" { move-column-right; }

            // Monitor focus
            "Mod+Shift+N" { focus-monitor-left; }
            "Mod+Shift+Left" { focus-monitor-left; }
            "Mod+Shift+E" { focus-monitor-down; }
            "Mod+Shift+Down" { focus-monitor-down; }
            "Mod+Shift+I" { focus-monitor-up; }
            "Mod+Shift+Up" { focus-monitor-up; }
            "Mod+Shift+O" { focus-monitor-right; }
            "Mod+Shift+Right" { focus-monitor-right; }

            // Move to monitor
            "Mod+Ctrl+Shift+N" { move-column-to-monitor-left; }
            "Mod+Ctrl+Shift+Left" { move-column-to-monitor-left; }
            "Mod+Ctrl+Shift+E" { move-column-to-monitor-down; }
            "Mod+Ctrl+Shift+Down" { move-column-to-monitor-down; }
            "Mod+Ctrl+Shift+I" { move-column-to-monitor-up; }
            "Mod+Ctrl+Shift+Up" { move-column-to-monitor-up; }
            "Mod+Ctrl+Shift+O" { move-column-to-monitor-right; }
            "Mod+Ctrl+Shift+Right" { move-column-to-monitor-right; }

            // Window resizing
            "Mod+Alt+N" { set-column-width "-10%"; }
            "Mod+Alt+O" { set-column-width "+10%"; }
            "Mod+Alt+E" { set-window-height "-10%"; }
            "Mod+Alt+I" { set-window-height "+10%"; }

            // Consume and expel
            "Mod+Comma" { consume-window-into-column; }
            "Mod+Period" { expel-window-from-column; }
            "Mod+BracketLeft" { consume-or-expel-window-left; }
            "Mod+BracketRight" { consume-or-expel-window-right; }

            // Workspace navigation (U/I + PageDown/PageUp)
            "Mod+U" { focus-workspace-down; }
            "Mod+PageDown" { focus-workspace-down; }
            "Mod+Shift+U" { move-workspace-down; }
            "Mod+Shift+PageDown" { move-workspace-down; }
            "Mod+Ctrl+U" { move-column-to-workspace-down; }
            "Mod+Ctrl+PageDown" { move-column-to-workspace-down; }

            // Named workspaces
            "Mod+1" { focus-workspace "Terminal"; }
            "Mod+2" { focus-workspace "Browser"; }
            "Mod+3" { focus-workspace "Code"; }
            "Mod+4" { focus-workspace "Chat"; }
            "Mod+5" { focus-workspace "Music"; }
            "Mod+6" { focus-workspace "Games"; }

            // Move windows to workspaces
            "Mod+Shift+1" { move-column-to-workspace "Terminal"; }
            "Mod+Shift+2" { move-column-to-workspace "Browser"; }
            "Mod+Shift+3" { move-column-to-workspace "Code"; }
            "Mod+Shift+4" { move-column-to-workspace "Chat"; }
            "Mod+Shift+5" { move-column-to-workspace "Music"; }
            "Mod+Shift+6" { move-column-to-workspace "Games"; }

            // System controls
            "Mod+V" { spawn "${pkgs.avizo}/bin/volumectl toggle-mute"; }
            "Mod+Equal" { spawn "${pkgs.avizo}/bin/volumectl up"; }
            "Mod+Minus" { spawn "${pkgs.avizo}/bin/volumectl down"; }
            "Mod+Shift+Equal" { spawn "${pkgs.avizo}/bin/lightctl up"; }
            "Mod+Shift+Minus" { spawn "${pkgs.avizo}/bin/lightctl down"; }

            // Screenshots
            "Print" { spawn "screenshot-region"; }
            "Shift+Print" { spawn "screenshot-full"; }
            "Mod+Print" { spawn "screenshot-region"; }

            // Idle inhibitor (moved from Mod+R)
            "Mod+Z" { spawn "sh" "-c" "pkill -x vigiland || vigiland &"; }

            "Mod+Shift+Q" { quit; }
        }
      '';

      # Home environment variables for proper cursor theme support
      sessionVariables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
      };
    };
  };
}
