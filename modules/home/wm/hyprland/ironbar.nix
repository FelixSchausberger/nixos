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
      hyprland-autoname-workspaces
    ];

    xdg.configFile."ironbar/config.json".text = builtins.toJSON {
      position = "top";
      anchor_to_edges = true;
      height = 32;
      margin = {
        top = 6;
        bottom = 0;
        left = 6;
        right = 6;
      };
      layer = "top";
      exclusive = true;

      start = [
        {
          type = "workspaces";
          hide_empty = false;
          format = "{name}";
          all_monitors = false;
          on_click_left = "hyprctl dispatch workspace {id}";
          on_scroll_up = "hyprctl dispatch workspace -1";
          on_scroll_down = "hyprctl dispatch workspace +1";
        }
      ];
      center = [
        {
          type = "script";
          cmd = "${pkgs.bash}/bin/bash ${./sysinfo.sh}";
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

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", monospace;
          font-size: 13px;
          color: #DBD3D3;
          font-weight: 500;
        }

        /* Main bar styling inspired by Spn4x */
        .bar {
          background-color: rgba(56, 58, 60, 0.85);
          border-radius: 12px;
          backdrop-filter: blur(20px);
          -webkit-backdrop-filter: blur(20px);
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
          border: 1px solid rgba(153, 147, 148, 0.3);
          margin: 6px;
        }

        /* Widget container styling */
        .container {
          background-color: transparent;
          padding: 3px 6px;
          margin: 0;
        }

        /* Individual items */
        .item {
          background-color: rgba(153, 147, 148, 0.1);
          padding: 4px 8px;
          margin: 0 2px;
          border-radius: 8px;
          border: 1px solid rgba(153, 147, 148, 0.2);
          transition: all 0.15s ease-in-out;
        }

        .item:hover {
          background-color: rgba(150, 97, 102, 0.3);
          color: #966166;
          box-shadow: 0 2px 8px rgba(150, 97, 102, 0.2);
        }

        /* Workspace styling */
        .workspaces {
          background-color: transparent;
          padding: 0;
        }

        .workspaces .item {
          padding: 4px 8px;
          margin: 0 1px;
          border-radius: 8px;
          min-width: 28px;
          text-align: center;
          background-color: rgba(2, 20, 27, 0.3);
          border: 1px solid rgba(153, 147, 148, 0.2);
        }

        .workspaces .item.focused {
          background-color: rgba(150, 97, 102, 0.4);
          color: #966166;
          font-weight: bold;
          box-shadow: 0 2px 8px rgba(150, 97, 102, 0.3);
          border: 1px solid rgba(150, 97, 102, 0.5);
        }

        .workspaces .item.visible {
          background-color: rgba(150, 97, 102, 0.2);
          color: #966166;
          border: 1px solid rgba(150, 97, 102, 0.3);
        }

        /* Clock styling */
        .clock {
          font-weight: bold;
          color: #966166;
          font-size: 14px;
        }

        /* Script (system info) styling */
        .script {
          color: #a6e3a1;
          font-weight: 500;
          font-size: 12px;
        }

        /* Volume styling */
        .volume {
          color: #f9e2af;
          font-size: 14px;
        }

        /* Battery/power styling */
        .upower {
          color: #f38ba8;
          font-size: 13px;
        }

        /* Focused window title styling */
        .focused {
          color: #DBD3D3;
          font-style: italic;
          opacity: 0.9;
          font-size: 12px;
          max-width: 200px;
        }

        /* Tooltips */
        .tooltip {
          background-color: rgba(56, 58, 60, 0.95);
          color: #DBD3D3;
          border: 1px solid rgba(153, 147, 148, 0.4);
          border-radius: 8px;
          padding: 8px 12px;
          font-size: 12px;
        }

        /* Additional styling for better visual consistency */
        .start, .center, .end {
          padding: 0 4px;
        }

        /* Custom styling for different widget states */
        .item.urgent {
          background-color: rgba(231, 130, 132, 0.4);
          color: #e78284;
          animation: pulse 1s infinite;
        }

        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.7; }
        }
      '';
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
      titles = "^$"

      # Custom icon mappings (monochrome style with proper app names and regex patterns)
      [icons]
      "zen-alpha" = "󰈹 Zen"
      "zen" = "󰈹 Zen"
      "firefox" = "󰈹 Firefox"
      "chromium-browser" = "󰈹 Chromium"
      "code-url-handler" = "󰨞 VS Code"
      "Code" = "󰨞 VS Code"
      "cursor" = "󰨞 Cursor"
      "dev.zed.Zed" = "󰨞 Zed"
      "zed" = "󰨞 Zed"
      "cosmic-files" = "󰉋 Files"
      "org.gnome.Nautilus" = "󰉋 Nautilus"
      "discord" = "󰙯 Discord"
      "Discord" = "󰙯 Discord"
      "steam" = "󰓓 Steam"
      "Steam" = "󰓓 Steam"
      "mpv" = "󰐹 MPV"
      "vlc" = "󰐹 VLC"
      "Spotify" = "󰓇 Spotify"
      "spotify" = "󰓇 Spotify"
      "obsidian" = "󰠮 Obsidian"
      "planify" = "󰄵 Planify"

      # Terminal applications (with regex patterns)
      "(?i).*(term|terminal).*" = "󰆍 Terminal"
      "wezterm" = "󰆍 Terminal"
      "cosmic-term" = "󰆍 Terminal"
      "alacritty" = "󰆍 Terminal"
      "com.mitchellh.ghostty" = "󰆍 Ghostty"
      "ghostty" = "󰆍 Ghostty"

      # GNOME apps (with regex patterns)
      "org.gnome.([A-Za-z]+)" = "󰾔 {match1}"
      "org.gnome.Calculator" = "󰃬 Calculator"
      "org.gnome.Settings" = "󰒓 Settings"
      "org.gnome.TextEditor" = "󰷈 Text Editor"
      "org.gnome.FileRoller" = "󰗄 Archive Manager"
      "org.gnome.Nautilus" = "󰉋 Files"

      # Other common patterns with regex
      "org.mozilla.([A-Za-z]+)" = "󰈹 {match1}"
      "org.kde.([A-Za-z]+)" = "󰌓 {match1}"
      "com.google.([A-Za-z]+)" = "󰊭 {match1}"
      "dev.([A-Za-z]+).([A-Za-z]+)" = "󰘦 {match2}"
      "io.github.[^.]+.([A-Za-z]+)" = "󰊤 {match1}"
      "md.([A-Za-z]+).([A-Za-z]+)" = "󰈙 {match2}"
      "com.([A-Za-z]+).([A-Za-z]+)" = "󰏒 {match2}"

      # Specific well-known apps
      "org.chromium.Chromium" = "󰈹 Chromium"
      "io.github.alainm23.planify" = "󰄵 Planify"
      "md.obsidian.Obsidian" = "󰠮 Obsidian"
      "com.spotify.Client" = "󰓇 Spotify"
      "org.telegram.desktop" = "󰔉 Telegram"
      "org.signal.Signal" = "󰭹 Signal"
      "com.slack.Slack" = "󰒱 Slack"
      "teams-for-linux" = "󰊻 Teams"
      "org.libreoffice.LibreOffice" = "󰈙 LibreOffice"
      "org.gimp.GIMP" = "󰄄 GIMP"
      "org.blender.Blender" = "󰂫 Blender"
      "com.github.johnfactotum.Foliate" = "󰂺 Foliate"
      "org.pwmt.zathura" = "󰈦 PDF"

      # Fallback with extracted app name from complex class names
      "([a-z]+\\.)+([A-Za-z]+)$" = "󰘔 {match2}"
      "DEFAULT" = "󰘔"

      # Format options
      [format]
      dedup = true
      class = "{icon}"
      title = "{icon}"

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
