{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: let
  niri = config.wm.niri.enable;
  hyprland = config.wm.hyprland.enable;
  enabled = niri || hyprland;
  c = config.lib.stylix.colors;
  fontMono = inputs.self.lib.fonts.families.monospace.name;
  ironbarPkg = inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.default;

  niriConfig = {
    name = "main";
    anchor_to_edges = false;
    position = "left";
    # Layer shell margins create the floating pill gap from screen edges
    margin_left = 8;
    margin_top = 8;
    margin_bottom = 8;

    start = [
      {
        type = "workspaces";
        all_monitors = false;
        # No name_map: workspaces appear only when Niri creates them
      }
    ];

    center = [
      {
        type = "custom";
        name = "clock";
        class = "clock";
        on_mouse_enter = "ironbar bar main show-popup clock";
        on_mouse_exit = "ironbar bar main hide-popup clock";
        bar = [
          {
            type = "label";
            label = "{{date '+%H'}}";
          }
          {
            type = "label";
            label = "{{date '+%M'}}";
          }
        ];
        popup = [
          {
            type = "label";
            class = "popup-time";
            label = "{{date '+%H:%M'}}";
          }
          {
            type = "label";
            class = "popup-weekday";
            label = "{{date '+%A'}}";
          }
          {
            type = "label";
            class = "popup-date";
            label = "{{date '+%-d %B %Y'}}";
          }
        ];
      }
    ];

    end = [
      {
        type = "custom";
        name = "sysinfo";
        class = "sysinfo";
        on_mouse_enter = "ironbar bar main show-popup sysinfo";
        on_mouse_exit = "ironbar bar main hide-popup sysinfo";
        bar = [
          {
            type = "label";
            label = "󰍛";
          }
        ];
        popup = [
          {
            type = "script";
            mode = "poll";
            cmd = "bash ${../niri/sysinfo.sh}";
            interval = 3000;
          }
        ];
      }
      {
        type = "custom";
        name = "vitals";
        class = "vitals";
        bar = [
          {
            type = "label";
            name = "vitals-score";
            label = "{{10000:vitals status --format ironbar | ${pkgs.jq}/bin/jq -r .text}}";
          }
        ];
      }
      {
        type = "custom";
        name = "stasis";
        class = "stasis";
        bar = [
          {
            type = "button";
            name = "stasis-btn";
            label = "{{10000:stasis-status | ${pkgs.jq}/bin/jq -r .text}}";
            on_click_left = "stasis-toggle";
          }
        ];
      }
      {
        type = "volume";
        format = "{icon}";
        max_volume = 100;
        icons = {
          volume_high = "󰕾";
          volume_medium = "󰖀";
          volume_low = "󰕿";
          muted = "󰖁";
        };
      }
      {
        type = "network_manager";
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
        icon_size = 18;
      }
    ];
  };

  hyprlandConfig = {
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
        on_scroll_up = "hyprctl dispatch workspace -1";
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
        cmd = "bash ${../niri/sysinfo.sh}";
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

  # CSS serves both WMs — pill border-radius works for both vertical and horizontal bars
  css = ''
    * {
      font-family: "${fontMono}";
      font-size: 13px;
      border: none;
      border-radius: 0;
    }

    window {
      background: transparent;
    }

    .bar {
      /* d9 ≈ 85% opacity — transparent enough for when niri blur ships */
      background-color: #${c.base00}d9;
      border-radius: 24px;
      padding: 12px 4px;
      /* Blur-ready — uncomment + lower alpha when niri blur is available:
         backdrop-filter: blur(20px) saturate(1.5); */
    }

    .start,
    .center,
    .end {
      background: transparent;
    }

    /* Reset GTK button defaults */
    button {
      background: transparent;
      border: none;
      border-radius: 0;
      padding: 0;
    }

    /* Workspaces */
    .workspaces {
      background: transparent;
    }

    .workspaces .item {
      background: #${c.base02};
      color: #${c.base05};
      border-radius: 8px;
      margin: 3px 4px;
      padding: 8px 4px;
      min-width: 40px;
      min-height: 40px;
      transition: all 500ms cubic-bezier(0.5, 1, 0.89, 1);
    }

    .workspaces .item:hover {
      background: #${c.base03};
    }

    .workspaces .item.focused {
      background: #${c.base0E};
      color: #${c.base00};
    }

    .workspaces .item.urgent {
      background: #${c.base08};
      color: #${c.base00};
    }

    /* Clock — bar icon, popup to the right */
    .clock {
      color: #${c.base09};
      padding: 4px 8px;
      min-width: 40px;
      min-height: 40px;
    }

    /* * { font-size } wins over container rules — target labels directly */
    .clock label {
      font-size: 18px;
    }

    /* Sysinfo — bar icon, popup to the right */
    .sysinfo {
      color: #${c.base09};
      padding: 4px 8px;
      min-width: 40px;
      min-height: 40px;
    }

    .sysinfo label {
      font-size: 18px;
    }

    /* Volume — centered icon, equal padding to prevent left-offset */
    .volume {
      color: #${c.base0D};
      padding: 4px 8px;
      min-width: 40px;
      min-height: 40px;
    }

    .volume label {
      font-size: 18px;
      min-width: 18px;
      margin: auto;
    }

    /* Network */
    .network_manager {
      color: #${c.base0C};
      padding: 4px 8px;
      min-width: 40px;
      min-height: 40px;
    }

    .network_manager label {
      font-size: 18px;
    }

    /* Vitals healthscore */
    .vitals {
      color: #${c.base0B};
      padding: 4px 8px;
      min-width: 40px;
      min-height: 40px;
    }

    .vitals label {
      font-size: 16px;
    }

    /* Stasis idle-manager toggle */
    .stasis {
      color: #${c.base04};
      padding: 4px 8px;
      min-width: 40px;
      min-height: 40px;
    }

    .stasis label,
    .stasis button {
      font-size: 16px;
    }

    .stasis.active {
      color: #${c.base0A};
    }

    /* Focused window title (Hyprland) */
    .focused {
      color: #${c.base05};
      padding: 4px 8px;
    }

    /* Script widget (Hyprland sysinfo inline) */
    .script {
      color: #${c.base05};
      padding: 4px 8px;
    }

    /* Tray — normalize icon sizes */
    .tray {
      padding: 4px 8px;
    }

    .tray image {
      min-width: 18px;
      min-height: 18px;
    }

    /* Popups — appear to the right for left-anchored bars */
    .popup-clock,
    .popup-sysinfo {
      background: #${c.base01};
      border: 1px solid #${c.base02};
      border-radius: 12px;
      padding: 10px 16px;
    }

    .popup-clock .popup-time {
      font-size: 28px;
      font-weight: bold;
      color: #${c.base09};
    }

    .popup-clock .popup-weekday {
      font-size: 13px;
      color: #${c.base05};
    }

    .popup-clock .popup-date {
      font-size: 13px;
      color: #${c.base04};
    }

    .popup-sysinfo .script {
      color: #${c.base05};
      font-size: 12px;
    }

    /* Tooltip */
    tooltip {
      background: #${c.base01};
      border: 1px solid #${c.base02};
      border-radius: 8px;
      padding: 6px 10px;
    }

    tooltip label {
      color: #${c.base05};
    }
  '';
in {
  config = lib.mkIf enabled {
    home.packages = [ironbarPkg];

    # Suppress nm-applet — network_manager widget handles network display
    xdg.configFile."autostart/nm-applet.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';

    xdg.configFile."ironbar/config.json".text =
      if niri
      then builtins.toJSON niriConfig
      else builtins.toJSON hyprlandConfig;

    xdg.configFile."ironbar/style.css".text = css;

    # Systemd service for niri — hyprland uses exec-once in its config
    systemd.user.services.ironbar = lib.mkIf niri {
      Unit = {
        Description = "Ironbar status bar";
        After = ["niri-session.target"];
        PartOf = ["niri-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${ironbarPkg}/bin/ironbar";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = ["niri-session.target"];
    };
  };
}
