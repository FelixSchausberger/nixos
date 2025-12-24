{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.niri;
in {
  imports = [
    inputs.walker.homeManagerModules.default
  ];

  config = lib.mkIf cfg.enable {
    # Walker program configuration
    programs.walker = {
      enable = true;
      runAsService = true;

      config = {
        # Search configuration
        search = {
          delay = 0;
          hide_icons = false;
          force_keyboard_focus = true;
        };

        # UI configuration
        ui = {
          fullscreen = false;
          show_initial_entries = true;
          anchors = {
            left = false;
            right = false;
            top = true;
            bottom = false;
          };
          margins = {
            top = 100;
            bottom = 0;
            left = 0;
            right = 0;
          };
        };

        # List configuration
        list = {
          height = 200;
          always_show = true;
          max_entries = 50;
        };

        # Module configuration
        modules = [
          {
            name = "applications";
            prefix = "";
            weight = 10;
          }
          {
            name = "runner";
            prefix = ">";
            weight = 4;
          }
          {
            name = "websearch";
            prefix = "?";
            weight = 7;
          }
          {
            name = "emoji";
            prefix = ":";
            weight = 1;
          }
          {
            name = "calc";
            prefix = "=";
            weight = 5;
          }
          {
            name = "clipboard";
            prefix = "v";
            weight = 8;
          }
          {
            name = "ssh";
            prefix = "s";
            weight = 2;
          }
          {
            name = "finder";
            prefix = "f";
            weight = 6;
          }
        ];

        # Websearch engines
        websearch = {
          engines = {
            google = "https://www.google.com/search?q={}";
            duckduckgo = "https://duckduckgo.com/?q={}";
            github = "https://github.com/search?q={}";
            nixpkgs = "https://search.nixos.org/packages?query={}";
            nixoptions = "https://search.nixos.org/options?query={}";
          };
        };

        # Clipboard configuration
        clipboard = {
          max_entries = 20;
          image_height = 300;
        };

        # Applications configuration
        applications = {
          show_description = true;
          show_generic = false;
          use_generic = false;
          desktop_actions = true;
        };

        # Runner configuration
        runner = {
          includes = ["/run/current-system/sw/bin" "${config.home.homeDirectory}/.nix-profile/bin"];
          excludes = [];
        };

        # Finder configuration
        finder = {
          max_entries = 30;
        };
      };

      # Custom CSS styling
      theme = {
        style = ''
          * {
            font-family: "JetBrainsMono Nerd Font";
            font-size: 13px;
            color: #cdd6f4;
            background: transparent;
          }

          #window {
            background: rgba(30, 30, 46, 0.9);
            border-radius: 12px;
            border: 2px solid #ffc87f;
            padding: 20px;
          }

          #input {
            background: rgba(49, 50, 68, 0.8);
            border-radius: 8px;
            border: none;
            padding: 12px 16px;
            font-size: 16px;
            color: #cdd6f4;
            margin-bottom: 10px;
          }

          #input:focus {
            background: rgba(49, 50, 68, 1.0);
            border: 1px solid #ffc87f;
          }

          #scroll {
            background: transparent;
          }

          .item {
            background: transparent;
            border-radius: 6px;
            padding: 8px 12px;
            margin: 2px 0;
          }

          .item:selected {
            background: rgba(255, 200, 127, 0.2);
          }

          .item:hover {
            background: rgba(255, 200, 127, 0.1);
          }

          .item .text {
            color: #cdd6f4;
          }

          .item .sub {
            color: #a6adc8;
            font-size: 12px;
          }

          .item:selected .text {
            color: #ffc87f;
          }
        '';
      };
    };

    # Configure clipboard history for walker
    home.packages = with pkgs; [
      wl-clipboard
    ];
  };
}
