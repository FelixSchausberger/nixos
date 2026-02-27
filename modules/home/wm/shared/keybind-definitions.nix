{lib, ...}: let
  # Directional key mappings for multi-layout support
  directions = {
    left = {
      colemak = "N";
      vim = "H";
      arrow = "Left";
      hyprDir = "l";
      resize = "-40 0";
    };
    right = {
      colemak = "O";
      vim = "L";
      arrow = "Right";
      hyprDir = "r";
      resize = "40 0";
    };
    up = {
      colemak = "I";
      vim = "K";
      arrow = "Up";
      hyprDir = "u";
      resize = "0 -40";
    };
    down = {
      colemak = "E";
      vim = "J";
      arrow = "Down";
      hyprDir = "d";
      resize = "0 40";
    };
  };
in {
  inherit directions;

  # Category-based keybind definitions
  # Each binding can specify WM-specific actions or be shared
  categories = {
    applications = {
      title = "Applications";
      key = "a";
      bindings = {
        terminal = {
          key = "T";
          desc = "Open Terminal";
          # Action defined per-WM in keybind generation
        };
        terminal-safe = {
          key = "Shift+T";
          desc = "Open Terminal (Safe Mode)";
          niriOnly = true;
        };
        launcher = {
          key = "D";
          desc = "Application Launcher (walker)";
        };
        browser = {
          key = "W";
          desc = "Web Browser";
          hyprlandOnly = true;
        };
        file-manager = {
          key = "E";
          desc = "File Manager";
          hyprlandOnly = true;
        };
        editor = {
          key = "C";
          desc = "Text Editor (helix)";
          hyprlandOnly = true;
        };
      };
    };

    window = {
      title = "Window Management";
      key = "w";
      bindings = {
        close = {
          key = "Q";
          desc = "Close Window";
        };
        float = {
          key = "V";
          desc = "Toggle Floating";
        };
        float-tiling = {
          key = "Shift+V";
          desc = "Switch Focus Between Floating and Tiling";
          niriOnly = true;
        };
        fullscreen = {
          key = "F";
          desc = "Fullscreen / Maximize Column";
        };
        fullscreen-window = {
          key = "Shift+F";
          desc = "Fullscreen Window / Maximize Window";
        };
        center = {
          key = "C";
          desc = "Center Window / Column";
        };
        center-visible = {
          key = "Ctrl+C";
          desc = "Center Visible Columns";
          niriOnly = true;
        };
        cycle-width = {
          key = "R";
          desc = "Cycle Column Width / Cycle Next";
        };
        cycle-height = {
          key = "Shift+R";
          desc = "Cycle Window Height / Cycle Previous";
        };
        reset-height = {
          key = "Ctrl+R";
          desc = "Reset Window Height";
          niriOnly = true;
        };
        consume-left = {
          key = "BracketLeft";
          desc = "Consume/Expel Window Left";
          niriOnly = true;
        };
        consume-right = {
          key = "BracketRight";
          desc = "Consume/Expel Window Right";
          niriOnly = true;
        };
        consume-into = {
          key = "Comma";
          desc = "Consume into Column";
          niriOnly = true;
        };
        expel-from = {
          key = "Period";
          desc = "Expel from Column";
          niriOnly = true;
        };
        group-toggle = {
          key = "G";
          desc = "Toggle Window Group";
          hyprlandOnly = true;
        };
        group-lock = {
          key = "Shift+G";
          desc = "Lock/Unlock Active Group";
          hyprlandOnly = true;
        };
      };
    };

    navigation = {
      title = "Navigation";
      key = "n";
      # Directional bindings are generated programmatically
      # This category includes multi-layout info
      info = {
        key = "question";
        desc = "Keyboard Layouts";
        submenu = [
          {desc = "Colemak-DH: N (left), E (down), I (up), O (right)";}
          {desc = "Vim: H (left), J (down), K (up), L (right)";}
          {desc = "Arrow: ← ↓ ↑ →";}
          {desc = "All layouts work identically - use your preferred keys";}
        ];
      };
      actions = {
        focus = {
          modifier = "";
          desc = "Focus {direction}";
          descNote = "(N/H/←)";
        };
        move = {
          modifier = "Ctrl+";
          desc = "Move Window {direction}";
          descNote = "(Ctrl+N/H/←)";
        };
        focus-monitor = {
          modifier = "Shift+";
          desc = "Focus Monitor {direction}";
          descNote = "(Shift+N/H/←)";
        };
        move-monitor = {
          modifier = "Ctrl+Shift+";
          desc = "Move to Monitor {direction}";
          descNote = "(Ctrl+Shift+N/H/←)";
        };
        resize = {
          modifier = "Alt+";
          desc = "Resize {direction}";
          descNote = "(Alt+N/H/←)";
          hyprlandOnly = true;
        };
      };
      special = {
        first = {
          key = "H";
          desc = "Focus First Column";
          niriOnly = true;
        };
        last = {
          key = "L";
          desc = "Focus Last Column";
          niriOnly = true;
        };
        move-first = {
          key = "F";
          desc = "Move Column to First";
          niriOnly = true;
        };
        move-last = {
          key = "T";
          desc = "Move Column to Last";
          niriOnly = true;
        };
      };
    };

    scratchpads = {
      title = "Scratchpads";
      key = "s";
      hyprlandOnly = true;
      bindings = {
        terminal = {
          key = "T";
          desc = "Terminal Scratchpad";
        };
        music = {
          key = "S";
          desc = "Music Player (spotify-player)";
        };
        planify = {
          key = "N";
          desc = "Planify Task Manager";
        };
        notes = {
          key = "O";
          desc = "Notes (Obsidian/Basalt)";
        };
        bluetui = {
          key = "B";
          desc = "Bluetooth Manager (bluetui)";
        };
        wifi = {
          key = "U";
          desc = "WiFi Manager (Impala)";
        };
        teams = {
          key = "Y";
          desc = "MS Teams";
          # Only available on x86_64-linux
        };
      };
    };

    workspaces = {
      title = "Workspaces";
      key = "space";
      bindings = {
        prev = {
          key = "P";
          desc = "Previous Workspace";
        };
        next = {
          key = "N";
          desc = "Next Workspace";
        };
        move-prev = {
          key = "K";
          desc = "Move Window to Previous Workspace";
        };
        move-next = {
          key = "J";
          desc = "Move Window to Next Workspace";
        };
        shift-up = {
          key = "U";
          desc = "Move Workspace Up";
          niriOnly = true;
        };
        shift-down = {
          key = "D";
          desc = "Move Workspace Down";
          niriOnly = true;
        };
        prev-alt = {
          key = "B";
          desc = "Previous Workspace (e-1)";
        };
        next-alt = {
          key = "F";
          desc = "Next Workspace (e+1)";
        };
        previous = {
          key = "T";
          desc = "Previous Workspace (Tab)";
        };
        # Numeric workspaces 1-9 generated programmatically
      };
    };

    screenshots = {
      title = "Screenshots";
      key = "p";
      bindings = {
        selection = {
          key = "S";
          desc = "Screenshot Selection";
        };
        fullscreen = {
          key = "F";
          desc = "Screenshot Full Screen";
        };
        window = {
          key = "W";
          desc = "Screenshot Window";
          niriOnly = true;
        };
        save-selection = {
          key = "A";
          desc = "Save Screenshot Selection";
          hyprlandOnly = true;
        };
        save-fullscreen = {
          key = "V";
          desc = "Save Screenshot Full Screen";
          hyprlandOnly = true;
        };
      };
    };

    system = {
      title = "System";
      key = "x";
      bindings = {
        lock = {
          key = "L";
          desc = "Lock Screen";
        };
        quit = {
          key = "Q";
          desc = "Quit Window Manager";
        };
        quit-alt = {
          key = "X";
          desc = "Quit Window Manager (Ctrl+Alt+Del)";
        };
        power-monitors = {
          key = "P";
          desc = "Power Off Monitors";
          niriOnly = true;
        };
        idle-inhibitor = {
          key = "Z";
          desc = "Toggle Idle Inhibitor";
          niriOnly = true;
        };
        debug-tint = {
          key = "D";
          desc = "Toggle Debug Tint / Test Notification";
        };
        emergency = {
          key = "E";
          desc = "Emergency Shell / Clear Notifications";
        };
        overview = {
          key = "O";
          desc = "Toggle Overview + Bar";
          niriOnly = true;
        };
      };
    };

    utilities = {
      title = "Utilities";
      key = "u";
      bindings = {
        clipboard = {
          key = "V";
          desc = "Clipboard History (walker)";
        };
        emoji = {
          key = "Period";
          desc = "Emoji Picker (walker)";
        };
        color-picker = {
          key = "Shift+C";
          desc = "Color Picker";
          hyprlandOnly = true;
        };
        resize-mode = {
          key = "R";
          desc = "Resize Mode";
          hyprlandOnly = true;
        };
      };
    };
  };
}
