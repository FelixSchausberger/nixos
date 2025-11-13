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
    # Add ironbar package
    home.packages = with pkgs; [
      inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Ironbar configuration file
    xdg.configFile."ironbar/config.json".text = builtins.toJSON {
      anchor_to_edges = true;
      position = "top";
      height = 28;
      start = [
        {
          type = "workspaces";
          all_monitors = false;
          name_map = {
            "Terminal" = "󰆍";
            "Browser" = "";
            "Code" = "";
            "Chat" = "󰭹";
            "Music" = "";
            "Games" = "";
          };
        }
      ];
      center = [
        {
          type = "focused";
          show_icon = true;
          show_title = true;
          icon_size = 24;
          truncate = {
            mode = "end";
            max_length = 50;
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
          type = "tray";
          icon_size = 16;
        }
        {
          type = "volume";
          format = "{icon} {percentage}%";
          max_volume = 100;
          icons = {
            volume_high = "";
            volume_medium = "";
            volume_low = "";
            muted = "";
          };
        }
        {
          type = "network_manager";
          format_ethernet = "󰈀 {ip}";
          format_wifi = "{icon} {ssid} {signal_strength}%";
          format_disconnected = "󰤭 Disconnected";
          icons = {
            wifi = {
              "0-25" = "󰤯";
              "25-50" = "󰤟";
              "50-75" = "󰤢";
              "75-100" = "󰤨";
            };
          };
        }
        {
          type = "clock";
          format = "%Y-%m-%d %H:%M:%S";
        }
      ];
    };

    # Ironbar CSS styling file
    xdg.configFile."ironbar/style.css".text = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
      }

      .bar {
        background-color: rgba(30, 30, 46, 0.9);
        border-bottom: 2px solid #ffc87f;
        padding: 4px 8px;
      }

      .start, .center, .end {
        background: transparent;
      }

      .workspaces {
        background: transparent;
      }

      .workspaces .item {
        background: rgba(49, 50, 68, 0.6);
        color: #a6adc8;
        border-radius: 6px;
        margin: 2px;
        padding: 4px 8px;
        min-width: 30px;
        transition: all 200ms ease;
      }

      .workspaces .item.focused {
        background: rgba(255, 200, 127, 0.8);
        color: #1e1e2e;
      }

      .workspaces .item.urgent {
        background: rgba(243, 139, 168, 0.8);
        color: #1e1e2e;
      }

      .focused {
        color: #cdd6f4;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 4px 8px;
      }

      .focused .icon {
        margin-right: 8px;
      }

      .tray {
        background: transparent;
      }

      .tray .item {
        background: rgba(49, 50, 68, 0.6);
        border-radius: 4px;
        margin: 1px;
        padding: 2px 4px;
      }

      .volume {
        color: #89b4fa;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 4px 8px;
        margin: 0 4px;
      }

      .network_manager {
        color: #94e2d5;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 4px 8px;
        margin: 0 4px;
      }

      .sys_info {
        color: #f9e2af;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 4px 8px;
        margin: 0 4px;
      }

      .script {
        color: #f9e2af;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 4px 8px;
        margin: 0 4px;
      }

      .clock {
        color: #fab387;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 4px 8px;
        margin: 0 4px;
      }

      button {
        background: transparent;
        border: none;
        border-radius: 0;
      }

      button:hover {
        background: rgba(255, 255, 255, 0.1);
        border-radius: 4px;
      }

      .popup {
        background: rgba(30, 30, 46, 0.95);
        border: 1px solid #ffc87f;
        border-radius: 8px;
        padding: 8px;
      }

      .popup-item {
        color: #cdd6f4;
        padding: 4px 8px;
        border-radius: 4px;
      }

      .popup-item:hover {
        background: rgba(255, 200, 127, 0.2);
      }
    '';

    # Systemd service to start ironbar
    systemd.user.services.ironbar = {
      Unit = {
        Description = "Ironbar status bar";
        After = ["niri-session.target"];
        PartOf = ["niri-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/ironbar";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = ["niri-session.target"];
    };
  };
}
