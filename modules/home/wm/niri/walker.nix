{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: let
  cfg = config.wm.niri;
in {
  config = lib.mkIf cfg.enable {
    # Add walker package
    home.packages = with pkgs; [
      inputs.walker.packages.${pkgs.system}.default
    ];

    # Walker styling
    xdg.configFile."walker/style.css".text = ''
      window {
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

    # Walker configuration
    xdg.configFile."walker/config.json".text = builtins.toJSON {
      search = {
        delay = 0;
      };
      ui = {
        anchors = {
          top = true;
          left = false;
          right = false;
          bottom = false;
        };
        margin = {
          top = 100;
          left = 0;
          right = 0;
          bottom = 0;
        };
        width = 600;
        height = 400;
      };
      list = {
        height = 200;
      };
      orientation = "vertical";
      hide_plugin_info = true;
      terminal = "${
        if cfg.terminal == "ghostty"
        then inputs.ghostty.packages.${pkgs.system}.default
        else pkgs.${cfg.terminal}
      }/bin/${cfg.terminal}";
      runner = {
        includes_binaries = true;
      };

      plugins = {
        applications = {
          enabled = true;
          weight = 10;
          max_entries = 50;
          prioritize_new = false;
          use_generic_name = false;
          actions = true;
        };

        calculator = {
          enabled = true;
          weight = 5;
          min_chars = 3;
        };

        clipboard = {
          enabled = true;
          weight = 8;
          max_entries = 20;
          exec_on_change = true;
          image_height = 300;
        };

        commands = {
          enabled = true;
          weight = 3;
        };

        dictionary = {
          enabled = true;
          weight = 2;
          min_chars = 3;
        };

        dmenu = {
          enabled = true;
          weight = 20;
        };

        finder = {
          enabled = true;
          weight = 6;
          max_entries = 30;
          placeholder = "Find files...";
        };

        runner = {
          enabled = true;
          weight = 4;
          max_entries = 15;
          includes_binaries = true;
          multiline = false;
        };

        ssh = {
          enabled = true;
          weight = 2;
          max_entries = 10;
        };

        symbols = {
          enabled = true;
          weight = 1;
          max_entries = 20;
        };

        websearch = {
          enabled = true;
          weight = 7;
          engines = {
            google = "https://www.google.com/search?q={}";
            duckduckgo = "https://duckduckgo.com/?q={}";
            github = "https://github.com/search?q={}";
            nixpkgs = "https://search.nixos.org/packages?query={}";
            nixoptions = "https://search.nixos.org/options?query={}";
          };
          default_engine = "duckduckgo";
        };
      };
    };
  };
}
