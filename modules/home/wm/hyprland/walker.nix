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
    inputs.walker.homeManagerModules.default
  ];
  config = lib.mkIf cfg.enable {
    # Walker program configuration
    programs.walker = {
      enable = true;
      runAsService = false;

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

        # Websearch engines - moved to top level as per walker config format
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
          max_entries = 200;
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

      # Custom CSS styling disabled temporarily to test basic functionality
      # theme = {
      #   style = ''
      #   * {
      #     font-family: "JetBrainsMono Nerd Font";
      #     font-size: 13px;
      #     color: #cdd6f4;
      #     background: transparent;
      #   }
      #   '';
      # };
    };

    # Configure clipboard history for walker
    home.packages = with pkgs; [
      wl-clipboard # Required for clipboard module
    ];
  };
}
