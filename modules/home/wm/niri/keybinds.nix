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
in {
  config = lib.mkIf cfg.enable {
    programs.niri.settings.binds = {
      # ===== APPLICATION SHORTCUTS =====
      "Mod+T" = {
        action.spawn = "${terminalPkg}/bin/${cfg.terminal}";
        hotkey-overlay.title = "Open Terminal";
      };

      "Mod+Shift+T" = {
        action.spawn = ["${terminalPkg}/bin/${cfg.terminal}" "-e" "${pkgs.fish}/bin/fish" "-c" "set -gx ZELLIJ_AUTO_START 0; exec fish"];
        hotkey-overlay.title = "Open Terminal (Safe Mode)";
      };

      "Mod+D" = {
        action.spawn = "walker";
        hotkey-overlay.title = "Application Launcher";
      };

      # ===== WINDOW MANAGEMENT =====
      "Mod+Q" = {
        action.close-window = {};
        hotkey-overlay.title = "Close Window";
      };

      "Mod+V" = {
        action.toggle-window-floating = {};
        hotkey-overlay.title = "Toggle Floating";
      };

      "Mod+Shift+V" = {
        action.switch-focus-between-floating-and-tiling = {};
        hotkey-overlay.title = "Switch Floating/Tiling Focus";
      };

      # ===== FULLSCREEN AND MAXIMIZE =====
      "Mod+F" = {
        action.maximize-column = {};
        hotkey-overlay.title = "Maximize Column";
      };

      "Mod+Shift+F" = {
        action.fullscreen-window = {};
        hotkey-overlay.title = "Fullscreen Window";
      };

      "Mod+Ctrl+F" = {
        action.maximize-window-to-edges = {};
        hotkey-overlay.title = "Maximize to Edges";
      };

      # ===== CENTER COLUMN =====
      "Mod+C" = {
        action.center-column = {};
        hotkey-overlay.title = "Center Column";
      };

      "Mod+Ctrl+C" = {
        action.center-visible-columns = {};
        hotkey-overlay.title = "Center Visible Columns";
      };

      # ===== COLUMN WIDTH AND WINDOW HEIGHT =====
      "Mod+R" = {
        action.switch-preset-column-width = {};
        hotkey-overlay.title = "Switch Preset Column Width";
      };

      "Mod+Shift+R" = {
        action.switch-preset-window-height = {};
        hotkey-overlay.title = "Switch Preset Window Height";
      };

      "Mod+Ctrl+R" = {
        action.reset-window-height = {};
        hotkey-overlay.title = "Reset Window Height";
      };

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

      # ===== WINDOW FOCUS =====
      # Vim keys
      "Mod+H".action.focus-column-left = {};
      "Mod+J".action.focus-window-down = {};
      "Mod+K".action.focus-window-up = {};
      "Mod+L".action.focus-column-right = {};

      # Colemak-DH
      "Mod+N".action.focus-column-left = {};
      "Mod+E".action.focus-window-down = {};
      "Mod+I".action.focus-window-up = {};
      "Mod+O".action.focus-column-right = {};

      # Arrow keys
      "Mod+Left".action.focus-column-left = {};
      "Mod+Down".action.focus-window-down = {};
      "Mod+Up".action.focus-window-up = {};
      "Mod+Right".action.focus-column-right = {};

      # First/last column
      "Mod+Home".action.focus-column-first = {};
      "Mod+End".action.focus-column-last = {};

      # ===== WINDOW MOVEMENT =====
      # Vim keys
      "Mod+Ctrl+H".action.move-column-left = {};
      "Mod+Ctrl+J".action.move-window-down = {};
      "Mod+Ctrl+K".action.move-window-up = {};
      "Mod+Ctrl+L".action.move-column-right = {};

      # Colemak-DH
      "Mod+Ctrl+N".action.move-column-left = {};
      "Mod+Ctrl+E".action.move-window-down = {};
      "Mod+Ctrl+I".action.move-window-up = {};
      "Mod+Ctrl+O".action.move-column-right = {};

      # Arrow keys
      "Mod+Ctrl+Left".action.move-column-left = {};
      "Mod+Ctrl+Down".action.move-window-down = {};
      "Mod+Ctrl+Up".action.move-window-up = {};
      "Mod+Ctrl+Right".action.move-column-right = {};

      # First/last column
      "Mod+Ctrl+Home".action.move-column-to-first = {};
      "Mod+Ctrl+End".action.move-column-to-last = {};

      # ===== MONITOR FOCUS =====
      # Vim keys
      "Mod+Shift+H".action.focus-monitor-left = {};
      "Mod+Shift+J".action.focus-monitor-down = {};
      "Mod+Shift+K".action.focus-monitor-up = {};
      "Mod+Shift+L".action.focus-monitor-right = {};

      # Colemak-DH
      "Mod+Shift+N".action.focus-monitor-left = {};
      "Mod+Shift+E".action.focus-monitor-down = {};
      "Mod+Shift+I".action.focus-monitor-up = {};
      "Mod+Shift+O".action.focus-monitor-right = {};

      # Arrow keys
      "Mod+Shift+Left".action.focus-monitor-left = {};
      "Mod+Shift+Down".action.focus-monitor-down = {};
      "Mod+Shift+Up".action.focus-monitor-up = {};
      "Mod+Shift+Right".action.focus-monitor-right = {};

      # ===== MOVE TO MONITOR =====
      # Vim keys
      "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = {};
      "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = {};
      "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = {};
      "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = {};

      # Colemak-DH
      "Mod+Shift+Ctrl+N".action.move-column-to-monitor-left = {};
      "Mod+Shift+Ctrl+E".action.move-column-to-monitor-down = {};
      "Mod+Shift+Ctrl+I".action.move-column-to-monitor-up = {};
      "Mod+Shift+Ctrl+O".action.move-column-to-monitor-right = {};

      # Arrow keys
      "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = {};
      "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = {};
      "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = {};
      "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = {};

      # ===== WORKSPACE NAVIGATION =====
      "Mod+Page_Down" = {
        action.focus-workspace-down = {};
        hotkey-overlay.title = "Next Workspace";
      };

      "Mod+Page_Up" = {
        action.focus-workspace-up = {};
        hotkey-overlay.title = "Previous Workspace";
      };

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
      "Mod+Ctrl+Page_Down" = {
        action.move-column-to-workspace-down = {};
        hotkey-overlay.title = "Move to Next Workspace";
      };

      "Mod+Ctrl+Page_Up" = {
        action.move-column-to-workspace-up = {};
        hotkey-overlay.title = "Move to Previous Workspace";
      };

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
      "Mod+Shift+Page_Down" = {
        action.move-workspace-down = {};
        hotkey-overlay.title = "Move Workspace Down";
      };

      "Mod+Shift+Page_Up" = {
        action.move-workspace-up = {};
        hotkey-overlay.title = "Move Workspace Up";
      };

      # ===== CONSUME AND EXPEL WINDOWS =====
      "Mod+BracketLeft" = {
        action.consume-or-expel-window-left = {};
        hotkey-overlay.title = "Consume/Expel Left";
      };

      "Mod+BracketRight" = {
        action.consume-or-expel-window-right = {};
        hotkey-overlay.title = "Consume/Expel Right";
      };

      "Mod+Comma" = {
        action.consume-window-into-column = {};
        hotkey-overlay.title = "Consume into Column";
      };

      "Mod+Period" = {
        action.expel-window-from-column = {};
        hotkey-overlay.title = "Expel from Column";
      };

      # ===== SCREENSHOTS =====
      "Print" = {
        action.screenshot = {};
        hotkey-overlay.title = "Screenshot (Selection)";
      };

      "Ctrl+Print" = {
        action.screenshot-screen = {};
        hotkey-overlay.title = "Screenshot (Full Screen)";
      };

      "Alt+Print" = {
        action.screenshot-window = {};
        hotkey-overlay.title = "Screenshot (Window)";
      };

      # ===== SYSTEM =====
      "Mod+F1" = {
        action.show-hotkey-overlay = {};
        hotkey-overlay.title = "Show Hotkey Overlay";
      };

      "Mod+Escape" = {
        action.toggle-debug-tint = {};
        hotkey-overlay.title = "Toggle Debug Tint";
      };

      "Mod+Shift+Escape" = {
        action.spawn = [
          "${terminalPkg}/bin/${cfg.terminal}"
          "-e"
          "${pkgs.bash}/bin/bash"
          "--norc"
          "-c"
          "touch /tmp/.nixos-emergency-mode && exec bash --norc"
        ];
        hotkey-overlay.title = "Emergency Shell";
      };

      "Mod+Shift+Q" = {
        action.quit = {};
        hotkey-overlay.title = "Quit Niri";
      };

      "Ctrl+Alt+Delete" = {
        action.quit = {};
        hotkey-overlay.title = "Quit Niri";
      };

      "Mod+Shift+P" = {
        action.power-off-monitors = {};
        hotkey-overlay.title = "Power Off Monitors";
      };

      # ===== LOCK SCREEN =====
      "Super+Alt+L" = {
        action.spawn = ["loginctl" "lock-session"];
        hotkey-overlay.title = "Lock Screen";
      };

      # ===== OVERVIEW + IRONBAR TOGGLE =====
      # Using spawn workaround since Niri doesn't support multiple actions per keybind yet
      # Reference: https://github.com/YaLTeR/niri/issues/965
      "Mod+Tab" = {
        action.spawn = ["bash" "-c" "niri msg action toggle-overview 2>/dev/null & ironbar bar main toggle-visible 2>/dev/null & wait"];
        hotkey-overlay.title = "Toggle Overview + Bar";
      };
    };
  };
}
