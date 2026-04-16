{cosmicLib, ...}: let
  # Build a Focus/Move/SwitchOutput/MoveToOutput tuple action for a direction
  mkDirAction = variant: dirStr:
    cosmicLib.cosmic.mkRON "enum" {
      inherit variant;
      value = [(cosmicLib.cosmic.mkRON "enum" dirStr)];
    };

  # Generate focus + move shortcuts for a direction (Colemak key + arrow key)
  mkDirShortcuts = colemakKey: arrowKey: dirStr: [
    {
      action = mkDirAction "Focus" dirStr;
      key = "Super+${colemakKey}";
    }
    {
      action = mkDirAction "Focus" dirStr;
      key = "Super+${arrowKey}";
    }
    {
      action = mkDirAction "Move" dirStr;
      key = "Super+Ctrl+${colemakKey}";
    }
    {
      action = mkDirAction "Move" dirStr;
      key = "Super+Ctrl+${arrowKey}";
    }
    {
      action = mkDirAction "SwitchOutput" dirStr;
      key = "Super+Shift+${colemakKey}";
    }
    {
      action = mkDirAction "SwitchOutput" dirStr;
      key = "Super+Shift+${arrowKey}";
    }
    {
      action = mkDirAction "MoveToOutput" dirStr;
      key = "Super+Ctrl+Shift+${colemakKey}";
    }
    {
      action = mkDirAction "MoveToOutput" dirStr;
      key = "Super+Ctrl+Shift+${arrowKey}";
    }
  ];

  mkSpawn = cmd:
    cosmicLib.cosmic.mkRON "enum" {
      variant = "Spawn";
      value = [cmd];
    };

  mkSystem = action:
    cosmicLib.cosmic.mkRON "enum" {
      variant = "System";
      value = [(cosmicLib.cosmic.mkRON "enum" action)];
    };
in {
  wayland.desktopManager.cosmic.shortcuts =
    [
      # Applications
      {
        action = mkSpawn "cosmic-term";
        description = cosmicLib.cosmic.mkRON "optional" "Open Terminal";
        key = "Super+T";
      }
      {
        action = mkSpawn "firefox";
        description = cosmicLib.cosmic.mkRON "optional" "Open Browser";
        key = "Super+Return";
      }

      # Window management
      {
        action = cosmicLib.cosmic.mkRON "enum" "Close";
        description = cosmicLib.cosmic.mkRON "optional" "Close window";
        key = "Super+Q";
      }
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

      # Workspace navigation
      {
        action = cosmicLib.cosmic.mkRON "enum" "PreviousWorkspace";
        description = cosmicLib.cosmic.mkRON "optional" "Previous workspace";
        key = "Super+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "PreviousWorkspace";
        key = "Super+Prior";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "NextWorkspace";
        description = cosmicLib.cosmic.mkRON "optional" "Next workspace";
        key = "Super+Shift+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "NextWorkspace";
        key = "Super+Next";
      }

      # Move window to workspace
      {
        action = cosmicLib.cosmic.mkRON "enum" "MoveToPreviousWorkspace";
        description = cosmicLib.cosmic.mkRON "optional" "Move to previous workspace";
        key = "Super+Ctrl+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "MoveToPreviousWorkspace";
        key = "Super+Ctrl+Prior";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "MoveToNextWorkspace";
        description = cosmicLib.cosmic.mkRON "optional" "Move to next workspace";
        key = "Super+Ctrl+Shift+U";
      }
      {
        action = cosmicLib.cosmic.mkRON "enum" "MoveToNextWorkspace";
        key = "Super+Ctrl+Next";
      }

      # System
      {
        action = mkSystem "Launcher";
        description = cosmicLib.cosmic.mkRON "optional" "Open launcher";
        key = "Super+D";
      }
      {
        action = mkSystem "BrightnessUp";
        key = "XF86MonBrightnessUp";
      }
      {
        action = mkSystem "BrightnessDown";
        key = "XF86MonBrightnessDown";
      }
      {
        action = mkSystem "VolumeRaise";
        key = "XF86AudioRaiseVolume";
      }
      {
        action = mkSystem "VolumeLower";
        key = "XF86AudioLowerVolume";
      }
      {
        action = mkSystem "Mute";
        key = "XF86AudioMute";
      }
    ]
    # Directional shortcuts: Colemak-DH (N/E/I/O) + arrows, Focus + Move + SwitchOutput + MoveToOutput
    ++ (mkDirShortcuts "N" "Left" "Left")
    ++ (mkDirShortcuts "E" "Down" "Down")
    ++ (mkDirShortcuts "I" "Up" "Up")
    ++ (mkDirShortcuts "O" "Right" "Right");
}
