{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.niri;

  # Package mappings for applications

  terminalPkg =
    if cfg.terminal == "ghostty"
    then inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
    else if cfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if cfg.terminal == "wezterm"
    then pkgs.wezterm
    else inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Directional key mappings for programmatic keybind generation
  directions = {
    left = {
      colemak = "N";
      vim = "H";
      arrow = "Left";
    };
    down = {
      colemak = "E";
      vim = "J";
      arrow = "Down";
    };
    up = {
      colemak = "I";
      vim = "K";
      arrow = "Up";
    };
    right = {
      colemak = "O";
      vim = "L";
      arrow = "Right";
    };
  };

  # Generate keybinds for a single direction with all 3 input schemes
  mkDirBind = modifier: dir: actionName: let
    keys = directions.${dir};
  in {
    "Mod+${modifier}${keys.colemak}".action.${actionName} = {};
    "Mod+${modifier}${keys.vim}".action.${actionName} = {};
    "Mod+${modifier}${keys.arrow}".action.${actionName} = {};
  };
in {
  config = lib.mkIf cfg.enable {
    programs.niri.settings.binds = lib.mkMerge [
      {
        # ===== APPLICATION SHORTCUTS =====
        "Mod+T".action.spawn = "${terminalPkg}/bin/${cfg.terminal}";

        "Mod+Shift+T".action.spawn = ["${terminalPkg}/bin/${cfg.terminal}" "-e" "${pkgs.fish}/bin/fish" "-c" "set -gx ZELLIJ_AUTO_START 0; exec fish"];

        "Mod+D".action.spawn = "walker";

        # ===== WINDOW MANAGEMENT =====
        "Mod+Q".action.close-window = {};

        "Mod+V".action.toggle-window-floating = {};

        "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = {};

        # ===== FULLSCREEN AND MAXIMIZE =====
        "Mod+F".action.maximize-column = {};

        "Mod+Shift+F".action.fullscreen-window = {};

        # ===== CENTER COLUMN =====
        "Mod+C".action.center-column = {};

        "Mod+Ctrl+C".action.center-visible-columns = {};

        # ===== COLUMN WIDTH AND WINDOW HEIGHT =====
        "Mod+R".action.switch-preset-column-width = {};

        "Mod+Shift+R".action.switch-preset-window-height = {};

        "Mod+Ctrl+R".action.reset-window-height = {};

        # Size adjustments (no overlay titles - repeated bindings)
        "Mod+Minus".action.set-column-width = "-10%";
        "Mod+Equal".action.set-column-width = "+10%";
        "Mod+Shift+Minus".action.set-window-height = "-10%";
        "Mod+Shift+Equal".action.set-window-height = "+10%";

        # Colemak-DH size adjustments
        "Mod+Alt+N".action.set-column-width = "-10%";
        "Mod+Alt+O".action.set-column-width = "+10%";
        "Mod+Alt+E".action.set-window-height = "-10%";
        "Mod+Alt+I".action.set-window-height = "+10%";

        # ===== WINDOW AND MONITOR FOCUS/MOVEMENT =====
        # First/last column shortcuts
        "Mod+Home".action.focus-column-first = {};
        "Mod+End".action.focus-column-last = {};
        "Mod+Ctrl+Home".action.move-column-to-first = {};
        "Mod+Ctrl+End".action.move-column-to-last = {};

        # ===== WORKSPACE NAVIGATION =====
        "Mod+Page_Down".action.focus-workspace-down = {};

        "Mod+Page_Up".action.focus-workspace-up = {};

        # Numeric workspaces (no titles - obvious from number)
        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;

        # ===== MOVE WINDOW TO WORKSPACE =====
        "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = {};

        "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = {};

        # Numeric (no titles)
        "Mod+Ctrl+1".action.move-column-to-workspace = 1;
        "Mod+Ctrl+2".action.move-column-to-workspace = 2;
        "Mod+Ctrl+3".action.move-column-to-workspace = 3;
        "Mod+Ctrl+4".action.move-column-to-workspace = 4;
        "Mod+Ctrl+5".action.move-column-to-workspace = 5;
        "Mod+Ctrl+6".action.move-column-to-workspace = 6;
        "Mod+Ctrl+7".action.move-column-to-workspace = 7;
        "Mod+Ctrl+8".action.move-column-to-workspace = 8;
        "Mod+Ctrl+9".action.move-column-to-workspace = 9;

        # ===== MOVE WORKSPACE =====
        "Mod+Shift+Page_Down".action.move-workspace-down = {};

        "Mod+Shift+Page_Up".action.move-workspace-up = {};

        # ===== CONSUME AND EXPEL WINDOWS =====
        "Mod+BracketLeft".action.consume-or-expel-window-left = {};

        "Mod+BracketRight".action.consume-or-expel-window-right = {};

        "Mod+Comma".action.consume-window-into-column = {};

        "Mod+Period".action.expel-window-from-column = {};

        # ===== SCREENSHOTS =====
        "Print".action.screenshot = {};

        "Ctrl+Print".action.screenshot-screen = {};

        "Alt+Print".action.screenshot-window = {};

        # ===== SYSTEM =====
        # Which-key keybind discovery (Mod+F1 = Help)
        "Mod+F1" = {
          action.spawn = [
            "${pkgs.wlr-which-key}/bin/wlr-which-key"
            "${config.xdg.configHome}/wlr-which-key/niri.yaml"
          ];
          hotkey-overlay.title = "Keybind Help";
        };

        "Mod+Escape".action.toggle-debug-tint = {};

        "Mod+Shift+Escape".action.spawn = [
          "${terminalPkg}/bin/${cfg.terminal}"
          "-e"
          "${pkgs.bash}/bin/bash"
          "--norc"
          "-c"
          "touch /tmp/.nixos-emergency-mode && exec bash --norc"
        ];

        "Mod+Shift+Q".action.quit = {};

        "Ctrl+Alt+Delete".action.quit = {};

        "Mod+Shift+P".action.power-off-monitors = {};

        # ===== LOCK SCREEN =====
        "Super+Alt+L".action.spawn = ["loginctl" "lock-session"];

        # ===== IDLE INHIBITOR =====
        "Mod+Z".action.spawn = ["stasis-toggle"];

        # ===== OVERVIEW + IRONBAR TOGGLE =====
        # Using spawn workaround since Niri doesn't support multiple actions per keybind yet
        # Reference: https://github.com/YaLTeR/niri/issues/965
        "Mod+Tab".action.spawn = ["bash" "-c" "niri msg action toggle-overview 2>/dev/null & ironbar bar main toggle-visible 2>/dev/null & wait"];
      }

      # Generated directional keybinds (Colemak-DH canonical + Vim + Arrow variants)
      # Window focus: Mod+N/E/I/O (and H/J/K/L, arrows)
      (lib.mkMerge [
        (mkDirBind "" "left" "focus-column-left")
        (mkDirBind "" "down" "focus-window-down")
        (mkDirBind "" "up" "focus-window-up")
        (mkDirBind "" "right" "focus-column-right")
      ])

      # Window movement: Mod+Ctrl+N/E/I/O
      (lib.mkMerge [
        (mkDirBind "Ctrl+" "left" "move-column-left")
        (mkDirBind "Ctrl+" "down" "move-window-down")
        (mkDirBind "Ctrl+" "up" "move-window-up")
        (mkDirBind "Ctrl+" "right" "move-column-right")
      ])

      # Monitor focus: Mod+Shift+N/E/I/O
      (lib.mkMerge [
        (mkDirBind "Shift+" "left" "focus-monitor-left")
        (mkDirBind "Shift+" "down" "focus-monitor-down")
        (mkDirBind "Shift+" "up" "focus-monitor-up")
        (mkDirBind "Shift+" "right" "focus-monitor-right")
      ])

      # Move to monitor: Mod+Shift+Ctrl+N/E/I/O
      (lib.mkMerge [
        (mkDirBind "Shift+Ctrl+" "left" "move-column-to-monitor-left")
        (mkDirBind "Shift+Ctrl+" "down" "move-column-to-monitor-down")
        (mkDirBind "Shift+Ctrl+" "up" "move-column-to-monitor-up")
        (mkDirBind "Shift+Ctrl+" "right" "move-column-to-monitor-right")
      ])
    ];
  };
}
