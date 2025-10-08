{cosmicLib, ...}: {
  wayland.desktopManager.cosmic.shortcuts = [
    # Application shortcuts (unified with niri/hyprland)
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
      action = cosmicLib.cosmic.mkRON "enum" {
        value = ["sh" "-c" "pkill -x vigiland || vigiland &"];
        variant = "Spawn";
      };
      description = cosmicLib.cosmic.mkRON "optional" "Toggle idle inhibitor";
      key = "Super+R";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "Close";
      key = "Super+Q";
    }

    # Window management (unified with niri/hyprland)
    {
      action = cosmicLib.cosmic.mkRON "enum" "Float";
      key = "Super+Space";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "Fullscreen";
      key = "Super+F";
    }

    # System shortcuts
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [(cosmicLib.cosmic.mkRON "enum" "Launcher")];
        variant = "System";
      };
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
  ];
}
