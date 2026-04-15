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
      position = "left";
      # width controls bar thickness; height fills screen for vertical bars
      width = 42;
      autohide = 300;
      start_hidden = true;
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
          # Two-line format renders naturally in a vertical bar without CSS rotation
          type = "clock";
          format = "%H\n%M";
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
          # Icon-only keeps items within the 42px bar width
          format = "{icon}";
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
          # Icon-only to fit the narrow vertical bar
          format_ethernet = "󰈀";
          format_wifi = "{icon}";
          format_disconnected = "󰤭";
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
          type = "tray";
          icon_size = 16;
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
        background-color: rgba(30, 30, 46, 0.92);
        /* Right border accent for vertical left bar */
        border-right: 2px solid #ffc87f;
        padding: 8px 4px;
        transition: all 200ms ease;
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
        /* Vertical margin between stacked workspace buttons */
        margin: 2px 4px;
        padding: 8px 4px;
        min-width: 30px;
        min-height: 30px;
        transition: all 200ms ease-in-out;
      }

      .workspaces .item:hover {
        background: rgba(255, 255, 255, 0.08);
      }

      .workspaces .item.focused {
        background: rgba(255, 200, 127, 0.8);
        color: #1e1e2e;
      }

      .workspaces .item.urgent {
        background: rgba(243, 139, 168, 0.8);
        color: #1e1e2e;
      }

      .tray {
        background: transparent;
      }

      .tray .item {
        background: rgba(49, 50, 68, 0.6);
        border-radius: 4px;
        margin: 2px 4px;
        padding: 4px;
      }

      .volume {
        color: #89b4fa;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 8px 4px;
        margin: 2px 4px;
        transition: all 200ms ease-in-out;
      }

      .network_manager {
        color: #94e2d5;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 8px 4px;
        margin: 2px 4px;
        transition: all 200ms ease-in-out;
      }

      .script {
        color: #f9e2af;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        padding: 8px 4px;
        margin: 2px 4px;
        transition: all 200ms ease-in-out;
      }

      .clock {
        color: #fab387;
        background: rgba(49, 50, 68, 0.6);
        border-radius: 6px;
        /* Stack hours/minutes vertically; font-size reduced to fit 42px width */
        font-size: 12px;
        padding: 8px 4px;
        margin: 2px 4px;
      }

      button {
        background: transparent;
        border: none;
        border-radius: 0;
      }

      button:hover {
        background: rgba(255, 255, 255, 0.08);
        border-radius: 6px;
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
