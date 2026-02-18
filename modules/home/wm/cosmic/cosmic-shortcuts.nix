{cosmicLib, ...}: let
  # Directional key mappings for programmatic keybind generation
  directions = {
    left = {
      colemak = "N";
      arrow = "Left";
      focusAction = "FocusLeft";
      moveAction = "MoveLeft";
      focusOutputAction = "FocusOutputLeft";
      moveToOutputAction = "MoveToOutputLeft";
    };
    down = {
      colemak = "E";
      arrow = "Down";
      focusAction = "FocusDown";
      moveAction = "MoveDown";
      focusOutputAction = "FocusOutputDown";
      moveToOutputAction = "MoveToOutputDown";
    };
    up = {
      colemak = "I";
      arrow = "Up";
      focusAction = "FocusUp";
      moveAction = "MoveUp";
      focusOutputAction = "FocusOutputUp";
      moveToOutputAction = "MoveToOutputUp";
    };
    right = {
      colemak = "O";
      arrow = "Right";
      focusAction = "FocusRight";
      moveAction = "MoveRight";
      focusOutputAction = "FocusOutputRight";
      moveToOutputAction = "MoveToOutputRight";
    };
  };

  # Generate shortcuts for a single direction with both input schemes
  mkDirShortcut = modifier: dir: actionKey: description: let
    keys = directions.${dir};
    action = cosmicLib.cosmic.mkRON "enum" keys.${actionKey};
  in [
    {
      inherit action;
      key = "Super+${modifier}${keys.colemak}";
      description = cosmicLib.cosmic.mkRON "optional" "${description} ${dir}";
    }
    {
      inherit action;
      key = "Super+${modifier}${keys.arrow}";
    }
  ];
in {
  wayland.desktopManager.cosmic.shortcuts =
    [
      # Application shortcuts
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = ["cosmic-term"];
          variant = "Spawn";
        };
        description = cosmicLib.cosmic.mkRON "optional" "Open Terminal";
        key = "Super+T";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = ["firefox"];
          variant = "Spawn";
        };
        description = cosmicLib.cosmic.mkRON "optional" "Open Browser";
        key = "Super+Return";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "Close";
        description = cosmicLib.cosmic.mkRON "optional" "Close window";
        key = "Super+Q";
      }

      # Window management
      {
        action = cosmicLib.cosmic.mkRON "enum" "Float";
        description = cosmicLib.cosmic.mkRON "optional" "Toggle floating";
        key = "Super+Space";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "Fullscreen";
        description = cosmicLib.cosmic.mkRON "optional" "Toggle fullscreen";
        key = "Super+F";
      }

      # Workspace navigation (U/I pattern)
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Previous")];
          variant = "SwitchWorkspace";
        };
        description = cosmicLib.cosmic.mkRON "optional" "Switch to workspace above";
        key = "Super+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Previous")];
          variant = "SwitchWorkspace";
        };
        key = "Super+Prior";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Next")];
          variant = "SwitchWorkspace";
        };
        description = cosmicLib.cosmic.mkRON "optional" "Switch to workspace below";
        key = "Super+Shift+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Next")];
          variant = "SwitchWorkspace";
        };
        key = "Super+Next";
      }

      # Move window to workspace
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Previous")];
          variant = "MoveToWorkspace";
        };
        description = cosmicLib.cosmic.mkRON "optional" "Move to workspace above";
        key = "Super+Ctrl+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Previous")];
          variant = "MoveToWorkspace";
        };
        key = "Super+Ctrl+Prior";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Next")];
          variant = "MoveToWorkspace";
        };
        description = cosmicLib.cosmic.mkRON "optional" "Move to workspace below";
        key = "Super+Ctrl+Shift+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Next")];
          variant = "MoveToWorkspace";
        };
        key = "Super+Ctrl+Next";
      }

      # System shortcuts
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "Launcher")];
          variant = "System";
        };
        description = cosmicLib.cosmic.mkRON "optional" "Open launcher";
        key = "Super+D";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "BrightnessUp")];
          variant = "System";
        };
        key = "XF86MonBrightnessUp";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "BrightnessDown")];
          variant = "System";
        };
        key = "XF86MonBrightnessDown";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "VolumeUp")];
          variant = "System";
        };
        key = "XF86AudioRaiseVolume";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "VolumeDown")];
          variant = "System";
        };
        key = "XF86AudioLowerVolume";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" {
          value = [(cosmicLib.cosmic.mkRON "enum" "VolumeMute")];
          variant = "System";
        };
        key = "XF86AudioMute";
      }
    ]
    # Generated directional shortcuts (Colemak-DH + Arrow variants)
    ++ (mkDirShortcut "" "left" "focusAction" "Focus window")
    ++ (mkDirShortcut "" "down" "focusAction" "Focus window")
    ++ (mkDirShortcut "" "up" "focusAction" "Focus window")
    ++ (mkDirShortcut "" "right" "focusAction" "Focus window")
    ++ (mkDirShortcut "Ctrl+" "left" "moveAction" "Move window")
    ++ (mkDirShortcut "Ctrl+" "down" "moveAction" "Move window")
    ++ (mkDirShortcut "Ctrl+" "up" "moveAction" "Move window")
    ++ (mkDirShortcut "Ctrl+" "right" "moveAction" "Move window")
    ++ (mkDirShortcut "Shift+" "left" "focusOutputAction" "Focus monitor")
    ++ (mkDirShortcut "Shift+" "down" "focusOutputAction" "Focus monitor")
    ++ (mkDirShortcut "Shift+" "up" "focusOutputAction" "Focus monitor")
    ++ (mkDirShortcut "Shift+" "right" "focusOutputAction" "Focus monitor")
    ++ (mkDirShortcut "Ctrl+Shift+" "left" "moveToOutputAction" "Move window to monitor")
    ++ (mkDirShortcut "Ctrl+Shift+" "down" "moveToOutputAction" "Move window to monitor")
    ++ (mkDirShortcut "Ctrl+Shift+" "up" "moveToOutputAction" "Move window to monitor")
    ++ (mkDirShortcut "Ctrl+Shift+" "right" "moveToOutputAction" "Move window to monitor");
}
