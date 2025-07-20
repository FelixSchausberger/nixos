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
      height = 38;
      margin = {
        top = 8;
        bottom = 0;
        left = 8;
        right = 8;
      };
      layer = "top";
      exclusive = true;

      start = [
        {
          type = "workspaces";
          hide_empty = false;
          format = "{name}";
          all_monitors = false;
        }
        {
          type = "focused";
          show_icon = false;
          show_title = true;
          truncate = {
            length = 40;
            mode = "end";
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
          format = ["{cpu_percent}%" "{memory_percent}%"];
        }
        {type = "volume";}
        {type = "upower";}
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
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
          color: #cdd6f4; /* Catppuccin Mocha text */
        }
        .background {
          background-color: rgba(17, 17, 27, 0.15);
          border-radius: 12px;
          backdrop-filter: blur(40px);
          -webkit-backdrop-filter: blur(40px);
          box-shadow: 0 4px 30px rgba(0, 0, 0, 0.1);
          border: 1px solid rgba(205, 214, 244, 0.1);
        }
        .item {
          background-color: transparent;
          padding: 0 6px;
          margin: 0 2px;
        }
        .item:hover {
          background-color: rgba(116, 199, 236, 0.1); /* Catppuccin Mocha sky */
        }
        .workspaces .item.focused {
          background-color: rgba(137, 180, 250, 0.2); /* Catppuccin Mocha blue */
          color: #89b4fa; /* Catppuccin Mocha blue */
          font-weight: bold;
        }
        .clock { font-weight: bold; }
        .sys_info, .volume, .upower, .script {
          color: inherit;
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
