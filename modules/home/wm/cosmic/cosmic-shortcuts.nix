{cosmicLib, ...}: {
  wayland.desktopManager.cosmic.shortcuts = [
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

    # Window focus (Colemak-DH N/E/I/O pattern)
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusLeft";
      description = cosmicLib.cosmic.mkRON "optional" "Focus window left";
      key = "Super+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusLeft";
      key = "Super+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusDown";
      description = cosmicLib.cosmic.mkRON "optional" "Focus window down";
      key = "Super+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusDown";
      key = "Super+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusUp";
      description = cosmicLib.cosmic.mkRON "optional" "Focus window up";
      key = "Super+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusUp";
      key = "Super+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusRight";
      description = cosmicLib.cosmic.mkRON "optional" "Focus window right";
      key = "Super+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusRight";
      key = "Super+Right";
    }

    # Window movement (Ctrl + N/E/I/O)
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveLeft";
      description = cosmicLib.cosmic.mkRON "optional" "Move window left";
      key = "Super+Ctrl+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveLeft";
      key = "Super+Ctrl+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveDown";
      description = cosmicLib.cosmic.mkRON "optional" "Move window down";
      key = "Super+Ctrl+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveDown";
      key = "Super+Ctrl+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveUp";
      description = cosmicLib.cosmic.mkRON "optional" "Move window up";
      key = "Super+Ctrl+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveUp";
      key = "Super+Ctrl+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveRight";
      description = cosmicLib.cosmic.mkRON "optional" "Move window right";
      key = "Super+Ctrl+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveRight";
      key = "Super+Ctrl+Right";
    }

    # Monitor focus (Shift + N/E/I/O)
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputLeft";
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor left";
      key = "Super+Shift+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputLeft";
      key = "Super+Shift+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputDown";
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor down";
      key = "Super+Shift+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputDown";
      key = "Super+Shift+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputUp";
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor up";
      key = "Super+Shift+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputUp";
      key = "Super+Shift+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputRight";
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor right";
      key = "Super+Shift+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "FocusOutputRight";
      key = "Super+Shift+Right";
    }

    # Move to monitor (Ctrl+Shift + N/E/I/O)
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputLeft";
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor left";
      key = "Super+Ctrl+Shift+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputLeft";
      key = "Super+Ctrl+Shift+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputDown";
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor down";
      key = "Super+Ctrl+Shift+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputDown";
      key = "Super+Ctrl+Shift+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputUp";
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor up";
      key = "Super+Ctrl+Shift+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputUp";
      key = "Super+Ctrl+Shift+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputRight";
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor right";
      key = "Super+Ctrl+Shift+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToOutputRight";
      key = "Super+Ctrl+Shift+Right";
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
  ];
}
