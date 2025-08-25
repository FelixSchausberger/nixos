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
      inputs.ironbar.packages.${pkgs.system}.default
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
            type = "script";
            cmd = "bash ${./sysinfo.sh}";
            interval = 3000;
            tooltip = "System Information";
          }
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
            type = "clock";
            format = "%a %b %d  %H:%M";
            tooltip_format = "%A, %B %d, %Y\n%H:%M:%S";
            on_click_left = "gnome-calendar";
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
            type = "upower";
            format = "{percentage}%";
          }
          {
            type = "script";
            cmd = "${pkgs.procps}/bin/pgrep -x vigiland > /dev/null && echo '☕' || echo ''";
            interval = 5000;
            tooltip = "Vigiland status";
            on_click_left = "${pkgs.procps}/bin/pgrep -x vigiland > /dev/null && ${pkgs.util-linux}/bin/pkill vigiland || ${inputs.self.packages.${pkgs.system}.vigiland}/bin/vigiland &";
          }
        ];
      };

      "ironbar/style.css".text = ''
        /* Clean ironbar configuration */
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
          color: #DBD3D3;
          font-weight: 500;
        }

        /* Main window */
        window {
          background: transparent;
        }

        /* Bar container */
        #bar, .bar {
          margin: 6px 15px 0px 15px;
          padding: 3px 8px;
          background-color: rgba(15, 18, 20, 0.3);
          border-radius: 12px;
          border: 2px solid rgba(153, 147, 148, 0.5);
        }

        /* Remove any other background styling */
        .background {
          background: transparent;
        }

        /* Container sections */
        .start, .center, .end {
          background: transparent;
        }

        /* Workspaces - circles only */
        .workspaces {
          background: transparent;
        }

        .workspaces .item {
          padding: 4px 8px;
          margin: 0 2px;
          background: transparent;
          border: none;
          font-size: 16px;
          color: rgba(219, 211, 211, 0.6);
        }

        .workspaces .item.focused {
          background: transparent;
          color: #966166;
          font-weight: bold;
        }

        .workspaces .item.visible {
          background: transparent;
          color: rgba(219, 211, 211, 0.8);
        }

        .workspaces .item:hover {
          background: transparent;
          color: #966166;
        }

        /* All other modules - NO backgrounds */
        .item {
          padding: 4px 8px;
          margin: 0 4px;
          background: transparent;
          border: none;
          color: #DBD3D3;
        }

        .item:hover {
          background: transparent;
          color: #966166;
        }

        /* Clock styling - no background */
        .clock {
          background: transparent;
          font-weight: bold;
          color: #966166;
          font-size: 14px;
        }

        .clock:hover {
          color: #966166;
          background: transparent;
        }

        /* Script (sysinfo) styling - WHITE TEXT */
        .script {
          background: transparent;
          color: #FFFFFF;
          font-weight: 500;
          font-size: 12px;
        }

        .script:hover {
          color: #FFFFFF;
          background: transparent;
        }

        /* Volume styling - no background */
        .volume {
          background: transparent;
          color: #f9e2af;
        }

        .volume:hover {
          color: #966166;
          background: transparent;
        }

        /* Battery/power styling - no background */
        .upower {
          background: transparent;
          color: #f38ba8;
        }

        .upower:hover {
          color: #966166;
          background: transparent;
        }

        /* Focused window - no background */
        .focused {
          background: transparent;
          color: #DBD3D3;
          font-size: 12px;
        }

        .focused:hover {
          background: transparent;
          color: #966166;
        }

        /* Tooltips */
        .tooltip {
          background-color: rgba(15, 18, 20, 0.9);
          color: #DBD3D3;
          border: 1px solid rgba(153, 147, 148, 0.5);
          border-radius: 8px;
          padding: 8px 12px;
          font-size: 12px;
        }
      '';
    };
  };
}
