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
      animation = "fromTop"
      margin = 50
      pinned = true

      [scratchpads.music]
      command = "${terminalPkg}/bin/${cfg.terminal} -e ${pkgs.spotify-player}/bin/spotify-player"
      class = "spotify-scratchpad"
      size = "75% 65%"
      animation = "fromTop"
      margin = 50
      pinned = true

      [scratchpads.planify]
      command = "${pkgs.planify}/bin/io.github.alainm23.planify"
      class = "io.github.alainm23.planify"
      size = "70% 60%"
      animation = "fromTop"
      margin = 50
      pinned = true

      [scratchpads.notes]
      command = "${
        if cfg.scratchpad.notesApp == "basalt"
        then inputs.self.packages.${pkgs.system}.basalt
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
      pinned = true

      [scratchpads.bluetui]
      command = "${terminalPkg}/bin/${cfg.terminal} -e ${pkgs.bluetui}/bin/bluetui"
      class = "bluetui-scratchpad"
      size = "60% 50%"
      animation = "fromTop"
      margin = 50
      pinned = true

      [scratchpads.impala]
      command = "${terminalPkg}/bin/${cfg.terminal} -e ${pkgs.impala}/bin/impala"
      class = "impala-scratchpad"
      size = "60% 50%"
      animation = "fromTop"
      margin = 50
      pinned = true

      ${lib.optionalString (pkgs.stdenv.hostPlatform.system == "x86_64-linux") ''
        [scratchpads.teams]
        command = "teams-for-linux"
        class = "teams-for-linux"
        size = "80% 75%"
        animation = "fromTop"
        margin = 50
        pinned = true
      ''}

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
        "float,class:^(spotify-scratchpad)$"
        "float,class:^(bluetui-scratchpad)$"
        "float,class:^(impala-scratchpad)$"
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
          "impala"|"i"|"wifi")
            ${pkgs.pyprland}/bin/pypr toggle impala
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
            echo "  impala (i)    - WiFi TUI Manager         [MOD + U]"
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
            echo "Usage: scratchpad [terminal|music|planify|notes|bluetui|impala|teams|menu|list]"
            echo "   or: scratchpad [t|s|p|o|b|i|ms|m|l]"
            ;;
          "menu"|"m")
            ${pkgs.pyprland}/bin/pypr menu
            ;;
          *)
            echo "Usage: scratchpad [terminal|music|planify|notes|bluetui|impala|teams|list]"
            echo "   or: scratchpad [t|s|p|o|b|i|ms|l|h]"
            echo "For help: scratchpad list"
            ;;
        esac
      '')
    ];
  };
}
