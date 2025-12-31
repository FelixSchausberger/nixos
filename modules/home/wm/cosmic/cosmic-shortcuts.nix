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
      action = cosmicLib.cosmic.mkRON "enum" "ToggleWindowFloating";
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
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus window left";
      key = "Super+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      key = "Super+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus window down";
      key = "Super+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      key = "Super+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus window up";
      key = "Super+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      key = "Super+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus window right";
      key = "Super+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Focus";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      key = "Super+Right";
    }

    # Window movement (Ctrl + N/E/I/O)
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window left";
      key = "Super+Ctrl+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      key = "Super+Ctrl+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window down";
      key = "Super+Ctrl+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      key = "Super+Ctrl+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window up";
      key = "Super+Ctrl+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      key = "Super+Ctrl+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window right";
      key = "Super+Ctrl+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "Move";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      key = "Super+Ctrl+Right";
    }

    # Monitor focus (Shift + N/E/I/O)
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor left";
      key = "Super+Shift+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      key = "Super+Shift+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor down";
      key = "Super+Shift+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      key = "Super+Shift+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor up";
      key = "Super+Shift+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      key = "Super+Shift+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Focus monitor right";
      key = "Super+Shift+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "SwitchOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      key = "Super+Shift+Right";
    }

    # Move to monitor (Ctrl+Shift + N/E/I/O)
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor left";
      key = "Super+Ctrl+Shift+N";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Left")];
      };
      key = "Super+Ctrl+Shift+Left";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor down";
      key = "Super+Ctrl+Shift+E";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Down")];
      };
      key = "Super+Ctrl+Shift+Down";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor up";
      key = "Super+Ctrl+Shift+I";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Up")];
      };
      key = "Super+Ctrl+Shift+Up";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      description = cosmicLib.cosmic.mkRON "optional" "Move window to monitor right";
      key = "Super+Ctrl+Shift+O";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        variant = "MoveToOutput";
        value = [(cosmicLib.cosmic.mkRON "enum" "Right")];
      };
      key = "Super+Ctrl+Shift+Right";
    }

    # Workspace navigation (U/I pattern)
    {
      action = cosmicLib.cosmic.mkRON "enum" "PreviousWorkspace";
      description = cosmicLib.cosmic.mkRON "optional" "Switch to workspace above";
      key = "Super+U";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "PreviousWorkspace";
      key = "Super+Prior";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "NextWorkspace";
      description = cosmicLib.cosmic.mkRON "optional" "Switch to workspace below";
      key = "Super+Shift+U";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "NextWorkspace";
      key = "Super+Next";
    }

    # Move window to workspace
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToPreviousWorkspace";
      description = cosmicLib.cosmic.mkRON "optional" "Move to workspace above";
      key = "Super+Ctrl+U";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToPreviousWorkspace";
      key = "Super+Ctrl+Prior";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToNextWorkspace";
      description = cosmicLib.cosmic.mkRON "optional" "Move to workspace below";
      key = "Super+Ctrl+Shift+U";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "MoveToNextWorkspace";
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
        value = [(cosmicLib.cosmic.mkRON "enum" "VolumeRaise")];
        variant = "System";
      };
      key = "XF86AudioRaiseVolume";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [(cosmicLib.cosmic.mkRON "enum" "VolumeLower")];
        variant = "System";
      };
      key = "XF86AudioLowerVolume";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [(cosmicLib.cosmic.mkRON "enum" "Mute")];
        variant = "System";
      };
      key = "XF86AudioMute";
    }

    # Idle inhibitor
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = ["sh" "-c" "pkill -x vigiland || vigiland &"];
        variant = "Spawn";
      };
      description = cosmicLib.cosmic.mkRON "optional" "Toggle idle inhibitor";
      key = "Super+Z";
    }
  ];
}
