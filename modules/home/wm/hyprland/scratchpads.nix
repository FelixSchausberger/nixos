{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.hyprland;

  # Terminal selection for scratchpads
  terminalPkg =
    if cfg.terminal == "ghostty"
    then pkgs.ghostty
    else if cfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if cfg.terminal == "wezterm"
    then pkgs.wezterm
    else pkgs.ghostty;

  # Music app command for scratchpad
  musicCommand =
    if cfg.scratchpad.musicApp == "spotify-player"
    then "${cfg.terminal} --class spotify-player-scratchpad -e spotify_player"
    else if cfg.scratchpad.musicApp == "spicetify"
    then "spicetify"
    else "spotify --no-zygote";

  # Notes app command for scratchpad
  notesCommand =
    if cfg.scratchpad.notesApp == "basalt"
    then "basalt"
    else "obsidian";
in {
  config = lib.mkIf cfg.enable {
    # Pyprland configuration with quality of life plugins
    xdg.configFile."hypr/pyprland.toml".text = ''
      [pyprland]
      plugins = ["scratchpads", "system_notifier", "shortcuts_menu", "workspaces_follow_focus", "shift_monitors", "toggle_dpms"]

      [scratchpads.terminal]
      command = "${terminalPkg}/bin/${cfg.terminal} --class terminal-scratchpad"
      class = "terminal-scratchpad"
      size = "80% 70%"
      animation = "fromTop"
      margin = 50

      [scratchpads.music]
      command = "${musicCommand}"
      # class = "${
        if cfg.scratchpad.musicApp == "spotify-player"
        then "spotify-player-scratchpad"
        else "Spotify"
      }"
      command = "${terminalPkg}/bin/${cfg.terminal} --class spotify-scratchpad -e ${pkgs.spotify-player}/bin/spotify-player"
      size = "75% 65%"
      animation = "fromTop"
      margin = 50

      [scratchpads.planify]
      command = "${pkgs.planify}/bin/io.github.alainm23.planify"
      class = "io.github.alainm23.planify"
      size = "70% 60%"
      animation = "fromTop"
      margin = 50

      [scratchpads.notes]
      command = "${
        if cfg.scratchpad.notesApp == "basalt"
        then pkgs.basalt
        else pkgs.obsidian
      }/bin/${notesCommand}"
      class = "${
        if cfg.scratchpad.notesApp == "basalt"
        then "basalt"
        else "obsidian"
      }"
      size = "85% 75%"
      animation = "fromTop"
      margin = 50

      [scratchpads.bluetui]
      command = "${terminalPkg}/bin/${cfg.terminal} --class bluetui-scratchpad -e ${pkgs.bluetui}/bin/bluetui"
      class = "bluetui-scratchpad"
      size = "60% 50%"
      animation = "fromTop"
      margin = 50

      ${lib.optionalString (pkgs.stdenv.hostPlatform.system == "x86_64-linux") ''
        [scratchpads.teams]
        command = "teams-for-linux"
        class = "teams-for-linux"
        size = "80% 75%"
        animation = "fromTop"
        margin = 50
      ''}

      # System Notifier - Monitor system events and send to swaync
      [system_notifier.sources.system_errors]
      command = "journalctl -f --since=now"
      parser = "system_errors"

      [system_notifier.sources.hypr_events]
      command = "journalctl -f -u hyprland --since=now"
      parser = "hypr_events"

      [system_notifier.parsers.system_errors]
      pattern = ".*(failed|error|critical|fatal).*"
      filter = "s/.*: (.*)/System Alert: \\1/"
      color = "#f38ba8"

      [system_notifier.parsers.hypr_events]
      pattern = ".*(started|stopped|reloaded).*"
      filter = "s/.*: (.*)/Hyprland: \\1/"
      color = "#a6e3a1"

      # Workspace Follow Focus - Better multi-monitor workspace management
      [workspaces_follow_focus]
      max_workspaces = 10

      # Shift Monitors - Move workspaces between monitors in carousel style
      [shift_monitors]
      # No additional configuration needed - works out of the box

      # Toggle DPMS - Toggle display power management for quick screen off
      [toggle_dpms]
      # No additional configuration needed - works out of the box

      # Shortcuts Menu - Discoverable command interface
      [shortcuts_menu.entries."󰣇 System"]
      " Reload Hyprland" = "${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl reload"
      "󰒲 Sleep System" = "systemctl suspend"
      "󰜉 Restart Hyprland" = "${pkgs.systemd}/bin/systemctl --user restart hyprland"
      "󰗼 Lock Screen" = "loginctl lock-session"
      "󰍹 Toggle Displays" = "${pkgs.pyprland}/bin/pypr toggle_dpms"

      [shortcuts_menu.entries."󰍹 Monitor Management"]
      "󰕔 Shift Workspaces Left" = "${pkgs.pyprland}/bin/pypr shift_monitors -1"
      "󰕒 Shift Workspaces Right" = "${pkgs.pyprland}/bin/pypr shift_monitors +1"
      "󰤄 Toggle DPMS (Screen Off)" = "${pkgs.pyprland}/bin/pypr toggle_dpms"

      [shortcuts_menu.entries."󰀻 Scratchpads"]
      "󱆃 Terminal" = "${pkgs.pyprland}/bin/pypr toggle terminal"
      "󰝚 Music" = "${pkgs.pyprland}/bin/pypr toggle music"
      "󰸘 Planify" = "${pkgs.pyprland}/bin/pypr toggle planify"
      "󱞎 Notes" = "${pkgs.pyprland}/bin/pypr toggle notes"
      "󰂯 Bluetooth" = "${pkgs.pyprland}/bin/pypr toggle bluetui"
      ${lib.optionalString (pkgs.stdenv.hostPlatform.system == "x86_64-linux") ''"󰊻 Teams" = "${pkgs.pyprland}/bin/pypr toggle teams"''}

      [shortcuts_menu.entries."󱓷 Applications"]
      "󰈹 Browser" = "$browser"
      "󰉋 File Manager" = "$fileManager"
      "󱓷 Walker" = "${inputs.walker.packages.${pkgs.system}.default}/bin/walker"
      "󰨞 Code Editor" = "${pkgs.helix}/bin/hx"

      [shortcuts_menu.entries."󰄀 Screenshots"]
      "󰩭 Area → Clipboard" = "${pkgs.grim}/bin/grim -g \\"$$(${pkgs.slurp}/bin/slurp)\\" - | ${pkgs.wl-clipboard}/bin/wl-copy"
      "󰍹 Full → Clipboard" = "${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy"
      "󰩭 Area → File" = "${pkgs.grim}/bin/grim -g \\"$$(${pkgs.slurp}/bin/slurp)\\" ~/Pictures/Screenshots/$$(date +'%Y-%m-%d_%H-%M-%S').png"
      "󰍹 Full → File" = "${pkgs.grim}/bin/grim ~/Pictures/Screenshots/$$(date +'%Y-%m-%d_%H-%M-%S').png"
    '';

    # Start pyprland with Hyprland
    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "${pkgs.pyprland}/bin/pypr"
      ];

      # Window rules for scratchpads (pyprland handles most of this automatically)
      windowrulev2 = [
        # Ensure scratchpad windows are floating and properly styled
        "float,class:^(terminal-scratchpad)$"
        "float,class:^(spotify-player-scratchpad)$"
        "float,class:^(bluetui-scratchpad)$"
        "opacity 0.95,class:^(terminal-scratchpad)$"
        "rounding 12,class:^(.*-scratchpad)$"
      ];
    };

    # Install pyprland for modern scratchpad management and convenience script
    home.packages = [
      pkgs.pyprland
      (pkgs.writeShellScriptBin "scratchpad" ''
        #!/${pkgs.bash}/bin/bash
        # Convenience wrapper for pyprland scratchpads

        case "$1" in
          "terminal"|"t")
            ${pkgs.pyprland}/bin/pypr toggle terminal
            ;;
          "music"|"s"|"spotify")
            ${pkgs.pyprland}/bin/pypr toggle music
            ;;
          "planify"|"p"|"plan")
            ${pkgs.pyprland}/bin/pypr toggle planify
            ;;
          "notes"|"n"|"obsidian"|"o")
            ${pkgs.pyprland}/bin/pypr toggle notes
            ;;
          "bluetui"|"b"|"bluetooth")
            ${pkgs.pyprland}/bin/pypr toggle bluetui
            ;;
          "teams"|"ms")
            ${lib.optionalString (pkgs.stdenv.hostPlatform.system == "x86_64-linux") "${pkgs.pyprland}/bin/pypr toggle teams"}
            ;;
          "list"|"l"|"help"|"h")
            echo "󰀻 Available scratchpads:"
            echo "  terminal (t)  - Terminal                 [MOD + T]"
            echo "  music (s)     - ${cfg.scratchpad.musicApp}                   [MOD + S]"
            echo "  planify (p)   - Planify Task Manager     [MOD + N]"
            echo "  notes (o)     - ${cfg.scratchpad.notesApp}                  [MOD + O]"
            echo "  bluetui (b)   - Bluetooth TUI Manager    [MOD + B]"
            ${lib.optionalString (pkgs.stdenv.hostPlatform.system == "x86_64-linux") ''echo "  teams (ms)    - MS Teams (work-specific) [MOD + Y]"''}
            echo ""
            echo "󱓷 Pyprland Quality of Life Features:"
            echo "  menu          - Interactive shortcuts menu     [MOD + /]"
            echo "  workspace +1  - Next workspace (follow focus)  [MOD + CTRL + K]"
            echo "  workspace -1  - Prev workspace (follow focus)  [MOD + CTRL + J]"
            echo ""
            echo "󰍹 Monitor Management:"
            echo "  shift left    - Move workspaces left           [MOD + SHIFT + Left]"
            echo "  shift right   - Move workspaces right          [MOD + SHIFT + Right]"
            echo "  toggle dpms   - Toggle displays on/off         [MOD + ALT + D]"
            echo ""
            echo "Usage: scratchpad [terminal|music|planify|notes|bluetui|teams|menu|list]"
            echo "   or: scratchpad [t|s|p|o|b|ms|m|l]"
            ;;
          "menu"|"m")
            ${pkgs.pyprland}/bin/pypr menu
            ;;
          *)
            echo "Usage: scratchpad [terminal|music|planify|notes|bluetui|teams|list]"
            echo "   or: scratchpad [t|s|p|o|b|ms|l|h]"
            echo "For help: scratchpad list"
            ;;
        esac
      '')
    ];
  };
}
