{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  imports = [
    inputs.walker.homeModules.default
  ];
  config = lib.mkIf cfg.enable {
    # Walker program configuration
    programs.walker = {
      enable = true;
      runAsService = true; # Background service for faster startup

      config = {
        # Search configuration
        search = {
          placeholder = "Search applications, files, and more...";
          delay = 0;
          hide_icons = false;
          force_keyboard_focus = true;
        };

        # UI configuration for lean appearance
        ui = {
          fullscreen = false;
          show_initial_entries = true;
          scroll_policy = "never";
          anchors = {
            left = false;
            right = false;
            top = true;
            bottom = false;
          };
          margins = {
            top = 10;
            bottom = 0;
            left = 0;
            right = 0;
            end = 0;
          };
        };

        # List configuration
        list = {
          height = 300;
          always_show = true;
          max_entries = 8;
        };

        # Module configuration
        modules = [
          {
            name = "applications";
            prefix = "";
            weight = 3;
          }
          {
            name = "runner";
            prefix = ">";
            weight = 2;
          }
          {
            name = "websearch";
            prefix = "?";
            weight = 1;
            engines = {
              google = "https://www.google.com/search?q={}";
              ddg = "https://duckduckgo.com/?q={}";
              github = "https://github.com/search?q={}";
              nixpkgs = "https://search.nixos.org/packages?query={}";
            };
          }
          {
            name = "emoji";
            prefix = ":";
            weight = 1;
          }
          {
            name = "calc";
            prefix = "=";
            weight = 1;
          }
          {
            name = "clipboard";
            prefix = "v";
            weight = 1;
            max_entries = 10;
          }
          {
            name = "hyprland";
            prefix = "w";
            weight = 2;
          }
        ];

        # Websearch engines
        websearch = {
          engines = {
            google = "https://www.google.com/search?q={}";
            ddg = "https://duckduckgo.com/?q={}";
            github = "https://github.com/search?q={}";
            nixpkgs = "https://search.nixos.org/packages?query={}";
            nix-options = "https://search.nixos.org/options?query={}";
          };
        };

        # Clipboard configuration
        clipboard = {
          max_entries = 20;
          image_height = 200;
        };

        # Applications configuration
        applications = {
          show_description = true;
          show_generic = false;
          use_generic = false;
          desktop_actions = false;
          context_aware_only = false;
        };

        # Runner configuration
        runner = {
          includes = ["/run/current-system/sw/bin" "${config.home.homeDirectory}/.nix-profile/bin"];
          excludes = [];
        };
      };

      # Custom CSS styling for lean and transparent appearance
      theme.style = ''
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
          color: #cdd6f4;
          background: transparent;
        }

        #window {
          background: rgba(30, 30, 46, 0.85);
          border-radius: 12px;
          border: 2px solid rgba(137, 180, 250, 0.6);
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
          backdrop-filter: blur(10px);
          -webkit-backdrop-filter: blur(10px);
        }

        #search {
          background: transparent;
          border: none;
          padding: 12px 16px;
          font-size: 14px;
          color: #cdd6f4;
          border-bottom: 1px solid rgba(137, 180, 250, 0.3);
        }

        #search:focus {
          outline: none;
          border-bottom-color: rgba(137, 180, 250, 0.8);
        }

        #search selection {
          background: rgba(137, 180, 250, 0.3);
        }

        #list {
          background: transparent;
          padding: 4px;
        }

        .item {
          padding: 8px 12px;
          border-radius: 6px;
          margin: 1px 4px;
          transition: all 0.15s ease-in-out;
          background: transparent;
        }

        .item:hover {
          background: rgba(137, 180, 250, 0.15);
        }

        .item:selected {
          background: rgba(137, 180, 250, 0.25);
          color: #1e1e2e;
          font-weight: 500;
        }

        .item:selected .sub {
          color: rgba(30, 30, 46, 0.8);
        }

        .item .text {
          color: #cdd6f4;
        }

        .item .sub {
          color: #a6adc8;
          font-size: 11px;
          opacity: 0.8;
        }

        .item .icon {
          margin-right: 8px;
          min-width: 20px;
          min-height: 20px;
        }

        /* Module-specific styling */
        .applications .item .text {
          color: #89b4fa;
        }

        .runner .item .text {
          color: #a6e3a1;
        }

        .websearch .item .text {
          color: #f9e2af;
        }

        .emoji .item .text {
          color: #f5c2e7;
        }

        .calc .item .text {
          color: #fab387;
        }

        .clipboard .item .text {
          color: #94e2d5;
        }

        .hyprland .item .text {
          color: #cba6f7;
        }

        /* Scrollbar styling */
        scrolledwindow scrollbar {
          background: transparent;
          width: 6px;
        }

        scrolledwindow scrollbar slider {
          background: rgba(137, 180, 250, 0.4);
          border-radius: 3px;
          min-height: 20px;
        }

        scrolledwindow scrollbar slider:hover {
          background: rgba(137, 180, 250, 0.6);
        }

        /* Entry animation */
        @keyframes fadeIn {
          from {
            opacity: 0;
            transform: translateY(-10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        .item {
          animation: fadeIn 0.2s ease-out;
        }
      '';
    };

    # Configure clipboard history for walker
    home.packages = with pkgs; [
      wl-clipboard # Required for clipboard module
    ];
  };
}
