{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: let
  niri = config.wm.niri.enable or false;
  hyprland = config.wm.hyprland.enable or false;
  # Ironbar is the bar of the hand-assembled "custom" shell. Wayle,
  # noctalia, and dms bring their own bars; keeping ironbar active
  # alongside them would duplicate layer-shell surfaces and tray ownership.
  customShell = (config.wm.shell or "custom") == "custom";
  enabled = (niri || hyprland) && customShell;
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
        # Numeric workspaces: index order matches niri's workspace order
        # (sort = "index" is the niri-specific ordering added in v0.19.0).
        sort = "index";
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
        # v0.19 profiles schema: single high icon plus threshold profiles
        # (matching is equal-to-or-below the threshold).
        icons = {
          volume = "󰕾";
          muted = "󰖁";
        };
        profiles = {
          medium = {
            when = 66.66;
            icons.volume = "󰖀";
          };
          low = {
            when = 33.33;
            icons.volume = "󰕿";
          };
        };
      }
      {
        type = "network_manager";
        icon_size = 18;
        use_default_profiles = false;
        # v0.19 reworked this module: device state renders via profiles
        # matching on type/state/signal_strength. Wifi buckets mirror the
        # old icons.wifi tiers (equal-to-or-below the strength bound).
        profiles = {
          wired_connected = {
            when = {
              type = "wired";
              state = "connected";
            };
            icon = "󰈀";
          };
          wired_disconnected = {
            when = {
              type = "wired";
              state = "disconnected";
            };
            icon = "󰤭";
          };
          wifi_disconnected = {
            when = {
              type = "wifi";
              state = "disconnected";
            };
            icon = "󰤭";
          };
          wifi_weak = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 25;
            };
            icon = "󰤯";
          };
          wifi_ok = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 50;
            };
            icon = "󰤟";
          };
          wifi_good = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 75;
            };
            icon = "󰤢";
          };
          wifi_excellent = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 100;
            };
            icon = "󰤨";
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
        # v0.19 profiles schema (see the niri config above).
        icons = {
          volume = "󰕾";
          muted = "󰖁";
        };
        profiles = {
          medium = {
            when = 66.66;
            icons.volume = "󰖀";
          };
          low = {
            when = 33.33;
            icons.volume = "󰕿";
          };
        };
        on_click_left = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
        on_scroll_up = "pactl set-sink-volume @DEFAULT_SINK@ +5%";
        on_scroll_down = "pactl set-sink-volume @DEFAULT_SINK@ -5%";
      }
      {
        type = "clock";
        format = "%a %b %d  %H:%M";
        tooltip_format = "%A, %B %d, %Y\n%H:%M:%S";
        # Interactive calendar (khal's ikhal); khal comes from the pim stack
        # in modules/home/tui/pim.nix. gnome-calendar is not installed.
        on_click_left = "ghostty -e ikhal";
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
      /* d9 ≈ 85% opacity — niri blurs the layer surface (layer-rule
         namespace "^ironbar"), so the pill reads as frosted glass. */
      background-color: #${c.base00}d9;
      border-radius: 24px;
      padding: 12px 4px;
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

  # Syncs bar visibility to the niri overview state: the bar shows only
  # while the overview is open (GNOME-style clean desktop). Asserts the
  # current state on start so a watcher restart re-syncs after an outage.
  overviewBarSync = pkgs.writeShellScript "niri-overview-bar-sync" ''
    niri=${config.programs.niri.package}/bin/niri
    ironbar=${ironbarPkg}/bin/ironbar
    sync() {
      if [ "$("$niri" msg --json overview-state | ${pkgs.jq}/bin/jq -r .is_open)" = "true" ]; then
        "$ironbar" bar main show
      else
        "$ironbar" bar main hide
      fi
    }
    sync
    # niri emits OverviewOpenedOrClosed on every overview state change.
    "$niri" msg --json event-stream |
      ${pkgs.jq}/bin/jq --unbuffered -r 'select(.OverviewOpenedOrClosed != null) | "tick"' |
      while read -r _; do sync; done
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
        # The overview-bar watcher only reacts to state changes, so the
        # default-visible bar is hidden once mapped (clean desktop at
        # login; the watcher shows it when the overview opens).
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 1; ${ironbarPkg}/bin/ironbar bar main hide'";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = ["niri-session.target"];
    };

    # Shows the bar only while the niri overview is open. ironbar's
    # crash-restart re-hides via ExecStartPost; the bar then stays hidden
    # until the next overview toggle (no event fires for a lost one).
    systemd.user.services.niri-overview-bar = lib.mkIf niri {
      Unit = {
        Description = "Sync Ironbar visibility to niri overview state";
        After = ["ironbar.service" "niri-session.target"];
        PartOf = ["ironbar.service"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${overviewBarSync}";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = ["niri-session.target"];
    };
  };
}
