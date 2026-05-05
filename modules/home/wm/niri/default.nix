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
    then pkgs.ghostty
    else if cfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if cfg.terminal == "wezterm"
    then pkgs.wezterm
    else pkgs.ghostty;

  fileManagerPkg = pkgs.cosmic-files;
in {
  imports = [
    inputs.cosmic-manager.homeManagerModules.default
    ./keybinds.nix
    ../shared/ironbar.nix # Floating pill bar with dynamic workspaces and popup widgets
    # Shared options and imports (imported once)
    ../shared-imports.nix # Shared homeManager module imports
    ../shared/options.nix
    ../shared/satty.nix
    ../shared/stasis.nix # Sophisticated Wayland idle manager with media detection
    ../shared/awww-coordinated.nix # awww wallpaper daemon, enabled via wm.awww options below
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
      type = lib.types.listOf (
        lib.types.submodule {
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
              type = lib.types.enum [
                "normal"
                "90"
                "180"
                "270"
                "flipped"
                "flipped-90"
                "flipped-180"
                "flipped-270"
              ];
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
        }
      );
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
        type = lib.types.enum [
          "obsidian"
          "basalt"
        ];
        default = "obsidian";
        description = "Notes application for scratchpad";
      };

      musicApp = lib.mkOption {
        type = lib.types.enum [
          "spotify"
          "spotify-player"
        ];
        default = "spotify";
        description = "Music application for scratchpad";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable awww wallpaper daemon for all niri hosts by default
    wm.awww = {
      enable = lib.mkDefault true;
      sessionTarget = lib.mkDefault "niri-session.target";
    };

    # Enable which-key for keybind discovery
    wm.which-key.enable = true;

    home = {
      packages = with pkgs;
        [
          # Niri-specific utilities
          terminalPkg # Default terminal for this profile (e.g. ghostty)
          swappy # Screenshot annotation
          cliphist # Clipboard history
          avizo # OSD for volume/brightness
          inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default # Wayland-native application launcher with plugins
          udiskie # Auto-mount
          cosmic-files # File manager
          # Cursor themes
          adwaita-icon-theme # For Adwaita cursor theme
          bibata-cursors # Better cursor theme
          gnome-themes-extra # Additional cursor themes
          hicolor-icon-theme # Base icon theme

          # Screenshot tools provided by shared/satty.nix
        ]
        ++ lib.optionals (cfg.browser != "zen") [
          browserPkg # Zen is provided by programs.zen-browser
        ];

      # Home environment variables for proper cursor theme support
      sessionVariables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
      };
    };

    xdg.configFile = lib.mkIf (cfg.terminal == "ghostty") {
      "ghostty/config.ghostty".text = ''
        command = ${pkgs.fish}/bin/fish
        shell-integration = fish
      '';
    };

    # Walker prefers DBus activation for Ghostty desktop entries, which can start
    # the daemon without opening a window. Override the desktop entry in
    # ~/.local/share/applications so launchers use direct Exec instead.
    xdg.desktopEntries."com.mitchellh.ghostty" = {
      name = "Ghostty";
      exec = "${pkgs.ghostty}/bin/ghostty --gtk-single-instance=true";
      terminal = false;
      type = "Application";
      categories = [
        "System"
        "TerminalEmulator"
      ];
      settings = {
        DBusActivatable = "false";
        StartupWMClass = "com.mitchellh.ghostty";
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
        always-center-single-column = true;
        default-column-width = {
          proportion = 0.5;
        };

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

      # Debug configuration for honoring XDG activation requests with invalid serial
      # Cannot be set via programs.niri.settings due to KDL generation limitation
      # See: https://github.com/sodiboo/niri-flake/issues
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
      # {command = ["${inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/ironbar"];}
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
        # Default rounded corners for all windows
        {
          geometry-corner-radius = {
            top-left = 12.0;
            top-right = 12.0;
            bottom-right = 12.0;
            bottom-left = 12.0;
          };
          clip-to-geometry = true;
        }
        {
          matches = [{app-id = "^scratchpad-.*";}];
          default-column-width = {
            proportion = 0.8;
          };
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
          default-column-width = {
            fixed = 400;
          };
          open-on-output = "focused";
        }
        {
          matches = [{app-id = "^it\\.mijorus\\.smile$";}];
          default-column-width = {
            fixed = 400;
          };
          open-on-output = "focused";
        }
        {
          matches = [{app-id = "^org\\.gnome\\.Calculator$";}];
          default-column-width = {
            fixed = 400;
          };
          open-on-output = "focused";
        }
        {
          matches = [{app-id = "^nm-connection-editor$";}];
          default-column-width = {
            fixed = 400;
          };
          open-on-output = "focused";
        }
        {
          matches = [{title = "^Picture-in-Picture$";}];
          default-column-width = {
            fixed = 480;
          };
          open-on-output = "focused";
        }
        # Neovim mode-based border colors (title set via vim.opt.titlestring)
        # NORMAL falls through to the Stylix default (base0D, blue)
        {
          matches = [{title = "\\[INSERT\\]";}];
          border.active = {
            color = "#a6e3a1";
          };
        }
        {
          matches = [
            {title = "\\[VISUAL\\]";}
            {title = "\\[V-LINE\\]";}
            {title = "\\[V-BLOCK\\]";}
          ];
          border.active = {
            color = "#cba6f7";
          };
        }
        {
          matches = [{title = "\\[COMMAND\\]";}];
          border.active = {
            color = "#fab387";
          };
        }
        {
          matches = [{title = "\\[REPLACE\\]";}];
          border.active = {
            color = "#f38ba8";
          };
        }
      ];

      # Place awww backdrop surface behind workspace thumbnails in overview
      layer-rules = [
        {
          matches = [{namespace = "^awww-daemonbackdrop$";}];
          place-within-backdrop = true;
        }
      ];

      # Keybindings imported from keybinds.nix
    };

    # niri-session.target activates after niri.service is ready (WAYLAND_DISPLAY
    # imported before sd_notify READY). Services depending on this target are
    # guaranteed to see WAYLAND_DISPLAY in their environment.
    systemd.user.targets.niri-session = {
      Unit = {
        Description = "Niri Wayland compositor session";
        Requires = ["niri.service"];
        After = ["niri.service"];
        BindsTo = ["graphical-session.target"];
      };
      Install.WantedBy = ["graphical-session.target"];
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
        ExecStart = "${
          inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite-unstable
        }/bin/xwayland-satellite";
        StandardOutput = "journal";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = ["niri-session.target"];
      };
    };
  };
}
