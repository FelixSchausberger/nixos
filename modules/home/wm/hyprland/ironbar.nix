{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.ironbar.packages.${pkgs.hostPlatform.system}.default
    ];

    xdg.configFile = {
      "ironbar/config.json".text = builtins.toJSON {
        position = "top";
        anchor_to_edges = false;
        height = 28;
        margin = {
          top = 6;
          bottom = 0;
          left = 15;
          right = 15;
        };
        layer = "top";
        exclusive = false;

        start = [
          {
            type = "workspaces";
            hide_empty = true;
            format = "○";
            format_focused = "●";
            all_monitors = false;
            on_click_left = "hyprctl dispatch workspace {id}";
            on_scroll_up = "hyprland dispatch workspace -1";
            on_scroll_down = "hyprctl dispatch workspace +1";
            exclude = ["special:.*"];
          }
        ];

        center = [
          {
            type = "focused";
            show_icon = true;
            show_title = true;
            icon_size = 16;
            truncate = {
              length = 50;
              mode = "middle";
            };
          }
        ];

        end = [
          {
            type = "script";
            cmd = "bash ${./sysinfo.sh}";
            interval = 3000;
            tooltip = "System Information";
          }
          {
            type = "volume";
            max_volume = 100;
            icons = {
              volume_high = "󰕾";
              volume_medium = "󰖀";
              volume_low = "󰕿";
              muted = "󰖁";
            };
            on_click_left = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
            on_scroll_up = "pactl set-sink-volume @DEFAULT_SINK@ +5%";
            on_scroll_down = "pactl set-sink-volume @DEFAULT_SINK@ -5%";
          }
          {
            type = "clock";
            format = "%a %b %d  %H:%M";
            tooltip_format = "%A, %B %d, %Y\n%H:%M:%S";
            on_click_left = "gnome-calendar";
          }
        ];
      };

      "ironbar/style.css".text = ''
        /* Individual module box styling for ironbar */
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
          color: #DBD3D3;
          font-weight: 500;
        }

        /* Main window and bar - transparent */
        window {
          background: transparent;
        }

        #bar, .bar {
          background: transparent;
          margin: 6px 15px 0px 15px;
        }

        .background {
          background: transparent;
        }

        /* Container sections - transparent */
        .start, .center, .end {
          background: transparent;
        }

        /* Default styling for all modules - individual boxes */
        .item {
          padding: 3px 8px;
          margin: 0 4px;
          background-color: rgba(15, 18, 20, 0.3);
          border-radius: 8px;
          border: none;
          color: #DBD3D3;
          min-width: 40px;
          transition: all 0.3s ease;
        }

        .item:hover {
          background-color: rgba(15, 18, 20, 0.7);
          color: #966166;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
        }

        /* Workspaces - individual boxes for each workspace */
        .workspaces {
          background: transparent;
        }

        .workspaces .item {
          padding: 4px 8px;
          margin: 0 2px;
          background-color: rgba(15, 18, 20, 0.3);
          border-radius: 8px;
          font-size: 16px;
          color: rgba(219, 211, 211, 0.6);
          min-width: 32px;
        }

        .workspaces .item.focused {
          background-color: rgba(150, 97, 102, 0.4);
          color: #966166;
          font-weight: bold;
        }

        .workspaces .item.visible {
          background-color: rgba(15, 18, 20, 0.5);
          color: rgba(219, 211, 211, 0.8);
        }

        .workspaces .item:hover {
          background-color: rgba(15, 18, 20, 0.7);
          color: #966166;
        }

        /* Clock styling with individual box */
        .clock {
          background-color: rgba(15, 18, 20, 0.3);
          font-weight: bold;
          color: #966166;
          font-size: 14px;
        }

        .clock:hover {
          background-color: rgba(15, 18, 20, 0.7);
          color: #966166;
        }

        /* Script (sysinfo) styling with box */
        .script {
          background-color: rgba(15, 18, 20, 0.3);
          color: #FFFFFF;
          font-weight: 500;
          font-size: 12px;
        }

        .script:hover {
          background-color: rgba(15, 18, 20, 0.7);
          color: #FFFFFF;
        }

        /* Volume styling with box */
        .volume {
          background-color: rgba(15, 18, 20, 0.3);
          color: #f9e2af;
        }

        .volume:hover {
          background-color: rgba(15, 18, 20, 0.7);
          color: #966166;
        }

        /* Focused window with box */
        .focused {
          background-color: rgba(15, 18, 20, 0.3);
          color: #DBD3D3;
          font-size: 12px;
        }

        .focused:hover {
          background-color: rgba(15, 18, 20, 0.7);
          color: #966166;
        }

        /* Tooltips */
        .tooltip {
          background-color: rgba(15, 18, 20, 0.9);
          color: #DBD3D3;
          border: 1px solid rgba(153, 147, 148, 0.3);
          border-radius: 8px;
          padding: 8px 12px;
          font-size: 12px;
        }
      '';
    };
  };
}
