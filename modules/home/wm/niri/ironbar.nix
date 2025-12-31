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

    # Ironbar configuration file - Vertical floating dock on left
    xdg.configFile."ironbar/config.json".text = builtins.toJSON {
      name = "main";

      # VERTICAL FLOATING DOCK - LEFT SIDE
      position = "left";
      anchor_to_edges = false; # Enables floating appearance

      # Floating positioning
      margin = {
        top = 8;
        bottom = 8;
        left = 8; # 8px from left edge
        right = 0;
      };

      # Vertical dock sizing
      height = 0; # Auto-height for vertical
      width = 56; # Dock width

      # Layer configuration
      layer = "overlay"; # Appear above windows
      exclusive = false; # Don't reserve space
      start_hidden = true; # Start hidden, toggle with Mod+Tab

      # Vertical layout
      start = [
        {
          type = "workspaces";
          all_monitors = false;
          # Dynamic workspaces - automatic naming
        }
      ];

      center = [
        # Empty for cleaner minimal dock
      ];

      end = [
        {
          type = "script";
          cmd = "bash ${./sysinfo.sh}";
          interval = 3000;
        }
        {
          type = "tray";
          icon_size = 20; # Larger for vertical
        }
        {
          type = "volume";
          format = "{icon}"; # Icon only for vertical
          max_volume = 100;
          icons = {
            volume_high = "";
            volume_medium = "";
            volume_low = "";
            muted = "";
          };
        }
        {
          type = "clock";
          format = "%H\n%M"; # Vertical time display
        }
      ];
    };

    # Ironbar CSS styling file with stylix colors
    xdg.configFile."ironbar/style.css".text = let
      # Use stylix colors directly as hex values
      # Stylix base16Scheme colors are already in hex format without #
      inherit (config.stylix.base16Scheme) base00;
      inherit (config.stylix.base16Scheme) base04;
      inherit (config.stylix.base16Scheme) base05;
      inherit (config.stylix.base16Scheme) base09;
      inherit (config.stylix.base16Scheme) base0A;
      inherit (config.stylix.base16Scheme) base0D;
    in ''
      * {
        font-family: "${config.stylix.fonts.monospace.name}";
        font-size: ${toString (config.stylix.fonts.sizes.applications - 1)}px;
        border: none;
        border-radius: 0;
      }

      window {
        background: transparent;
      }

      .bar {
        background-color: rgba(17, 17, 27, 0.75); /* base00 with 75% opacity */
        border: 1px solid rgba(245, 194, 231, 0.25); /* base09 accent border */
        border-radius: 28px; /* Rounded pill shape */
        padding: 12px 8px; /* Vertical padding larger */
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35),
                    0 2px 6px rgba(0, 0, 0, 0.2); /* Depth shadow */
        /* Future blur support:
         * backdrop-filter: blur(16px);
         */
      }

      .start, .center, .end {
        background: transparent;
      }

      .workspaces {
        background: transparent;
        padding: 4px 0;
      }

      .workspaces .item {
        background: rgba(30, 30, 46, 0.60);
        color: ${base04};
        border-radius: 14px; /* Round workspace buttons */
        margin: 4px 0; /* Vertical spacing */
        padding: 8px;
        min-width: 40px;
        min-height: 40px; /* Square-ish buttons */
        transition: all 180ms cubic-bezier(0.4, 0.0, 0.2, 1);
      }

      .workspaces .item.focused {
        background: rgba(245, 194, 231, 0.80); /* base09 highlight */
        color: ${base00};
        transform: scale(1.1);
        box-shadow: 0 0 12px rgba(245, 194, 231, 0.4); /* Glow effect */
      }

      .workspaces .item.urgent {
        background: rgba(245, 194, 231, 0.80);
        color: ${base00};
        animation: pulse 1.5s ease-in-out infinite;
      }

      @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.6; }
      }

      /* Widget styling for vertical dock */
      .tray, .volume, .script, .clock {
        background: rgba(30, 30, 46, 0.50);
        border-radius: 12px;
        padding: 8px;
        margin: 4px 0; /* Vertical margins */
        transition: all 150ms ease;
      }

      .tray:hover, .volume:hover, .script:hover, .clock:hover {
        background: rgba(30, 30, 46, 0.75);
        transform: translateX(-2px); /* Subtle shift left on hover */
      }

      .volume { color: ${base0D}; }
      .script { color: ${base0A}; }
      .clock { color: ${base09}; }

      .tray .item {
        background: rgba(30, 30, 46, 0.60);
        border-radius: 10px;
        padding: 6px;
        margin: 2px 0;
      }

      button {
        background: transparent;
        border: none;
      }

      button:hover {
        background: rgba(245, 194, 231, 0.20);
        border-radius: 8px;
      }

      .popup {
        background: rgba(17, 17, 27, 0.92);
        border: 1px solid rgba(245, 194, 231, 0.30);
        border-radius: 12px;
        padding: 8px;
        /* Future blur support:
         * backdrop-filter: blur(16px);
         */
      }

      .popup-item {
        color: ${base05};
        padding: 6px 10px;
        border-radius: 6px;
        transition: background 100ms ease;
      }

      .popup-item:hover {
        background: rgba(245, 194, 231, 0.30);
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
