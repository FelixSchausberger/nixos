{cosmicLib, ...}: {
  wayland.desktopManager.cosmic.shortcuts = [
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [
          "firefox"
        ];
        variant = "Spawn";
      };
      description = cosmicLib.cosmic.mkRON "optional" "Open Firefox";
      key = "Super+B";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" "Close";
      key = "Super+Q";
    }
    # {
    #   action = cosmicLib.cosmic.mkRON "enum" "Disable";
    #   key = "Super+M";
    # }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [
          (cosmicLib.cosmic.mkRON "enum" "BrightnessDown")
        ];
        variant = "System";
      };
      key = "XF86MonBrightnessDown";
    }
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [
          (cosmicLib.cosmic.mkRON "enum" "Launcher")
        ];
        variant = "System";
      };
      key = "Super";
    }
  ];
}
