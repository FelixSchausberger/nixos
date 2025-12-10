{
  config,
  lib,
  pkgs,
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
      plugins = ["scratchpads"]

      [scratchpads.terminal]
      command = "${terminalPkg}/bin/${cfg.terminal}"
      class = "terminal-scratchpad"
      size = "80% 70%"
      position = "50% 15%"
      animation = "fromTop"
      margin = 50
      lazy = true
      unfocus = "hide"

      [scratchpads.music]
      command = "${terminalPkg}/bin/${cfg.terminal} -e ${pkgs.spotify-player}/bin/spotify-player"
      class = "spotify-scratchpad"
      size = "75% 65%"
      position = "50% 15%"
      animation = "fromTop"
      margin = 50
      lazy = true
      unfocus = "hide"

      [scratchpads.planify]
      command = "${pkgs.planify}/bin/io.github.alainm23.planify"
      class = "io.github.alainm23.planify"
      size = "70% 60%"
      position = "50% 20%"
      animation = "fromTop"
      margin = 50
      lazy = true
      unfocus = "hide"

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
      position = "50% 12%"
      animation = "fromTop"
      margin = 50
      lazy = true
      unfocus = "hide"

      [scratchpads.bluetui]
      command = "${terminalPkg}/bin/${cfg.terminal} -e ${pkgs.bluetui}/bin/bluetui"
      class = "bluetui-scratchpad"
      size = "60% 50%"
      position = "50% 25%"
      animation = "fromTop"
      margin = 50
      lazy = true
      unfocus = "hide"

      [scratchpads.impala]
      command = "${terminalPkg}/bin/${cfg.terminal} -e ${pkgs.impala}/bin/impala"
      class = "impala-scratchpad"
      size = "60% 50%"
      position = "50% 25%"
      animation = "fromTop"
      margin = 50
      lazy = true
      unfocus = "hide"

      ${lib.optionalString (pkgs.hostPlatform.system == "x86_64-linux") ''
        [scratchpads.teams]
        command = "teams-for-linux"
        class = "teams-for-linux"
        size = "80% 75%"
        position = "50% 12%"
        animation = "fromTop"
        margin = 50
        lazy = true
        unfocus = "hide"
      ''}

    '';

    # Start pyprland with Hyprland
    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "${pkgs.pyprland}/bin/pypr"
      ];

      # Window rules for scratchpads (comprehensive floating and positioning)
      windowrulev2 = [
        # Scratchpad rules
        "float,class:^(scratchpad-.*)$"
        "size 80% 80%,class:^(scratchpad-.*)$"
        "center,class:^(scratchpad-.*)$"
        "opacity 0.95,class:^(scratchpad-.*)$"
        # Scratchpad help popup
        "float,class:^(scratchpad-help)$"
        "center,class:^(scratchpad-help)$"
        "size 600 400,class:^(scratchpad-help)$"
        "rounding 12,class:^(scratchpad-help)$"
        "opacity 0.95,class:^(scratchpad-help)$"
        "stayfocused,class:^(scratchpad-help)$"
        # Terminal scratchpads
        "float,class:^(terminal-scratchpad)$"
        "size 80% 70%,class:^(terminal-scratchpad)$"
        "center,class:^(terminal-scratchpad)$"
        "opacity 0.95,class:^(terminal-scratchpad)$"
        "rounding 12,class:^(terminal-scratchpad)$"
        # Music scratchpad
        "float,class:^(spotify-scratchpad)$"
        "size 75% 65%,class:^(spotify-scratchpad)$"
        "center,class:^(spotify-scratchpad)$"
        "opacity 0.95,class:^(spotify-scratchpad)$"
        "rounding 12,class:^(spotify-scratchpad)$"
        # Bluetooth scratchpad
        "float,class:^(bluetui-scratchpad)$"
        "size 60% 50%,class:^(bluetui-scratchpad)$"
        "center,class:^(bluetui-scratchpad)$"
        "opacity 0.95,class:^(bluetui-scratchpad)$"
        "rounding 12,class:^(bluetui-scratchpad)$"
        # WiFi scratchpad
        "float,class:^(impala-scratchpad)$"
        "size 60% 50%,class:^(impala-scratchpad)$"
        "center,class:^(impala-scratchpad)$"
        "opacity 0.95,class:^(impala-scratchpad)$"
        "rounding 12,class:^(impala-scratchpad)$"
        # Application scratchpads
        "float,class:^(io.github.alainm23.planify)$"
        "size 70% 60%,class:^(io.github.alainm23.planify)$"
        "center,class:^(io.github.alainm23.planify)$"
        "opacity 0.95,class:^(io.github.alainm23.planify)$"
        "rounding 12,class:^(io.github.alainm23.planify)$"
        # Notes app (Obsidian/Basalt)
        "float,class:^(obsidian)$"
        "size 85% 75%,class:^(obsidian)$"
        "center,class:^(obsidian)$"
        "opacity 0.95,class:^(obsidian)$"
        "rounding 12,class:^(obsidian)$"
        "float,class:^(basalt)$"
        "size 85% 75%,class:^(basalt)$"
        "center,class:^(basalt)$"
        "opacity 0.95,class:^(basalt)$"
        "rounding 12,class:^(basalt)$"
        # Global scratchpad styling
        "noborder,class:^(.*-scratchpad)$"
        "noshadow,class:^(.*-scratchpad)$"
        "pin,class:^(.*-scratchpad)$"
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
          "impala"|"i"|"wifi")
            ${pkgs.pyprland}/bin/pypr toggle impala
            ;;
          "list"|"l"|"help"|"h")
            echo "󰀻 Available scratchpads:"
            echo "  terminal (t)  - Terminal                 [MOD + T]"
            echo "  music (s)     - ${cfg.scratchpad.musicApp}                   [MOD + S]"
            echo "  planify (p)   - Planify Task Manager     [MOD + N]"
            echo "  notes (o)     - ${cfg.scratchpad.notesApp}                  [MOD + O]"
            echo "  bluetui (b)   - Bluetooth TUI Manager    [MOD + B]"
            echo "  impala (i)    - WiFi TUI Manager         [MOD + U]"
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
            echo "Usage: scratchpad [terminal|music|planify|notes|bluetui|impala|menu|list]"
            echo "   or: scratchpad [t|s|p|o|b|i|m|l]"
            ;;
          "menu"|"m")
            ${pkgs.pyprland}/bin/pypr menu
            ;;
          *)
            echo "Usage: scratchpad [terminal|music|planify|notes|bluetui|impala|list]"
            echo "   or: scratchpad [t|s|p|o|b|i|l|h]"
            echo "For help: scratchpad list"
            ;;
        esac
      '')
    ];
  };
}
