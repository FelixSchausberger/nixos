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
    home.packages = with pkgs; [
      inputs.ironbar.packages.${pkgs.system}.default
      hyprland-autoname-workspaces # Automatic workspace naming
      (writeShellScriptBin "ironbar-autohide" ''
        #!/${bash}/bin/bash

        # Monitor active window and hide/show ironbar accordingly
        handle() {
          case $1 in
            fullscreen*)
              # Hide ironbar when entering fullscreen
              pkill -SIGUSR1 ironbar || true
              ;;
            closefullscreen*)
              # Show ironbar when exiting fullscreen
              pkill -SIGUSR2 ironbar || true
              ;;
          esac
        }

        # Listen to hyprland events
        socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
          handle "$line"
        done
      '')
    ];

    # Ironbar configuration with Catppuccin theme
    xdg.configFile."ironbar/config.json".text = builtins.toJSON {
      position = "top";
      anchor_to_edges = true;
      height = 42;
      margin = {
        top = 8;
        bottom = 0;
        left = 8;
        right = 8;
      };
      layer = "top";
      exclusive = true;

      # Module layout
      start = [
        {
          type = "workspaces";
          # Keep fallback icons for empty workspaces
          name_map = {
            "1" = "";
            "2" = "󰈹";
            "3" = "";
            "4" = "";
            "5" = "";
            "6" = "󰙯";
            "7" = "";
            "8" = "";
            "9" = "";
            "10" = "";
          };
          hide_empty = false;
          all_monitors = false;
          # Allow dynamic workspace names from hyprland-autoname-workspaces
          format = "{name}";
        }
        {
          type = "focused";
          show_icon = true;
          show_title = true;
          icon_size = 20;
          truncate = {
            mode = "end";
            length = 50;
          };
        }
      ];
      center = [
        {
          type = "clock";
          format = "%H:%M";
        }
      ];
      end = [
        {
          type = "sys_info";
          format = [" {cpu_percent}%" " {memory_percent}%"];
        }
        {
          type = "volume";
        }
        {
          type = "network_manager";
        }
        {
          type = "upower";
        }
      ];

      # Style configuration with Catppuccin colors
      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
          color: #cdd6f4;
        }

        .background {
          background-color: rgba(30, 30, 46, 0.8);
          border-radius: 12px;
          border: 2px solid rgba(137, 180, 250, 0.3);
        }

        .item {
          background-color: transparent;
          border-radius: 8px;
          margin: 2px 4px;
          padding: 4px 8px;
          transition: all 0.2s ease-in-out;
        }

        .item:hover {
          background-color: rgba(137, 180, 250, 0.2);
        }

        /* Workspace styling */
        .workspaces .item {
          min-width: 30px;
          background-color: rgba(69, 71, 90, 0.6);
          color: #a6adc8;
        }

        .workspaces .item.focused {
          background-color: rgba(137, 180, 250, 0.8);
          color: #1e1e2e;
          font-weight: bold;
        }

        .workspaces .item.urgent {
          background-color: rgba(243, 139, 168, 0.8);
          color: #1e1e2e;
        }

        /* Focused window */
        .focused {
          color: #89b4fa;
        }

        /* Clock */
        .clock {
          color: #fab387;
          font-weight: bold;
        }

        /* System info */
        .sys_info {
          color: #a6e3a1;
        }

        /* Volume */
        .volume {
          color: #f9e2af;
        }

        .volume.muted {
          color: #f38ba8;
        }

        /* Network */
        .network_manager {
          color: #94e2d5;
        }

        .network_manager.disconnected {
          color: #f38ba8;
        }

        /* Bluetooth */
        .bluetooth {
          color: #cba6f7;
        }

        .bluetooth.off {
          color: #6c7086;
        }

        /* Battery */
        .battery {
          color: #a6e3a1;
        }

        .battery.low {
          color: #f38ba8;
        }

        .battery.charging {
          color: #a6e3a1;
        }

        /* Notifications */
        .notifications {
          color: #f5c2e7;
        }

        .notifications.dnd {
          color: #6c7086;
        }

        /* Popup styling */
        .popup {
          background-color: rgba(30, 30, 46, 0.95);
          border: 2px solid rgba(137, 180, 250, 0.5);
          border-radius: 12px;
          padding: 12px;
          margin: 8px;
        }

        .popup .item {
          border-radius: 6px;
          padding: 6px 10px;
        }

        .popup .item:hover {
          background-color: rgba(137, 180, 250, 0.3);
        }
      '';
    };

    # Ironbar service with auto-start
    systemd.user.services.ironbar = {
      Unit = {
        Description = "Ironbar status bar";
        Documentation = "https://github.com/JakeStanger/ironbar";
        PartOf = ["hyprland-session.target"];
        After = ["hyprland-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${inputs.ironbar.packages.${pkgs.system}.default}/bin/ironbar --config %h/.config/ironbar/config.json";
        Restart = "always";
        RestartSec = "5";
      };

      Install.WantedBy = ["hyprland-session.target"];
    };

    # Hyprland autoname workspaces service
    systemd.user.services.hyprland-autoname-workspaces = {
      Unit = {
        Description = "Automatically rename workspaces based on focused window";
        Documentation = "https://github.com/hyprland-community/hyprland-autoname-workspaces";
        PartOf = ["hyprland-session.target"];
        After = ["hyprland-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.hyprland-autoname-workspaces}/bin/hyprland-autoname-workspaces";
        Restart = "always";
        RestartSec = "5";
        Environment = "PATH=${lib.makeBinPath [pkgs.hyprland]}";
      };

      Install.WantedBy = ["hyprland-session.target"];
    };

    # Additional XDG configuration files
    xdg.configFile."hyprland-autoname-workspaces/config.toml".text = ''
      # Exclude certain windows from renaming
      [exclude]
      titles = ["^$"]

      # Custom icon mappings
      [icons]
      "zen-alpha" = "🌐"
      "zen" = "🌐"
      "firefox" = "🌐"
      "chromium-browser" = "🌐"
      "code-url-handler" = ""
      "Code" = ""
      "cursor" = ""
      "cosmic-files" = ""
      "org.gnome.Nautilus" = ""
      "discord" = "󰙯"
      "Discord" = "󰙯"
      "steam" = ""
      "Steam" = ""
      "mpv" = ""
      "vlc" = ""
      "Spotify" = ""
      "spotify" = ""
      "obsidian" = ""
      "planify" = ""
      "wezterm" = ""
      "cosmic-term" = ""
      "alacritty" = ""
      "DEFAULT" = "{class}"

      # Format options
      [format]
      dedup = true
      class = "{class}"
      title = "{title}"

      # Client matching
      [client]
      separator = " | "
      empty_label = "Empty"

      # Workspace formatting
      [workspace]
      rename_inactive = true
      empty_name = "{id}"
    '';
  };
}
