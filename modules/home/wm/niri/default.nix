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
    then inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    else if cfg.browser == "firefox"
    then pkgs.firefox
    else if cfg.browser == "chromium"
    then pkgs.chromium
    else pkgs.firefox;

  terminalPkg =
    if cfg.terminal == "ghostty"
    then inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
    else if cfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if cfg.terminal == "wezterm"
    then pkgs.wezterm
    else inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;

  fileManagerPkg = pkgs.cosmic-files;
  # Toggle script for synchronized overview + ironbar visibility
  # Note: Niri doesn't natively support multiple actions per keybind yet (issue #965)
  # Workaround: Use shell script to execute both commands
in {
  imports = [
    inputs.cosmic-manager.homeManagerModules.default
    inputs.wayland-pipewire-idle-inhibit.homeModules.default
    ./keybinds.nix
    ./walker.nix
    ./ironbar.nix
    # Shared options and imports (imported once)
    ../shared-imports.nix # Shared homeManager module imports
    ../shared/options.nix
    ../shared/wayland-pipewire-idle-inhibit.nix
    ../shared/satty.nix
    ../shared/vigiland-simple.nix
    (import ../shared/swww-coordinated.nix "niri-session.target") # Coordinated workspace and backdrop wallpapers
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
    # Enable stylix theming for niri
    stylix.targets.niri.enable = true;

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
    };

    # Niri declarative configuration using programs.niri.settings
    # Provided by niri-flake's home-manager module (auto-imported via nixosModules.niri)
    programs.niri.settings = {
      # Input configuration
      input = {
        keyboard.xkb = {
          layout = "de";
          variant = "";
          options = "terminate:ctrl_alt_bksp";
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

      # Window rules for rounded corners
      window-rules = [
        {
          geometry-corner-radius = {
            top-left = 12.0;
            top-right = 12.0;
            bottom-right = 12.0;
            bottom-left = 12.0;
          };
          clip-to-geometry = true;
        }
      ];

      # Hotkey overlay configuration
      hotkey-overlay.skip-at-startup = true;

      # Overview configuration
      overview = {
        backdrop-color = "transparent"; # Allow blurred wallpaper to show through
        zoom = 0.25;
      };

      # Layer rules for wallpaper
      layer-rules = [
        # swww workspace wallpapers (not in backdrop)
        {
          matches = [{namespace = "^swww-daemon$";}];
        }

        # swww backdrop: blurred wallpapers for overview
        {
          matches = [{namespace = "^swww-daemonbackdrop$";}];
          place-within-backdrop = true;
        }
      ];

      # Debug configuration for honoring XDG activation requests with invalid serial
      # TODO: Cannot be set via programs.niri.settings due to KDL generation issue
      # Add manually to ~/.config/niri/config.kdl if needed:
      # debug { honor-xdg-activation-with-invalid-serial; }

      # Environment variables
      environment = {
        TERMINAL = "${terminalPkg}/bin/${cfg.terminal}";
        BROWSER = "${browserPkg}/bin/${cfg.browser}";
        FILEMANAGER = "${fileManagerPkg}/bin/${cfg.fileManager}";
      };

      # Startup applications
      spawn-at-startup = [
        {command = ["${pkgs.avizo}/bin/avizo-service"];}
        {command = ["${inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/ironbar"];}
        {command = ["${pkgs.udiskie}/bin/udiskie" "--tray"];}
        {command = ["${pkgs.wl-clipboard}/bin/wl-paste" "--type" "text" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"];}
        {command = ["${pkgs.wl-clipboard}/bin/wl-paste" "--type" "image" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"];}
      ];

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

      # Keybindings are now configured in keybinds.nix
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
        ExecStart = "${inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite-unstable}/bin/xwayland-satellite";
        StandardOutput = "journal";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = ["niri-session.target"];
      };
    };
  };
}
