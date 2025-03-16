{cosmicLib, ...}: {
  wayland.desktopManager.cosmic.stateFile = {
    "com.system76.CosmicBackground" = {
      entries = {
        wallpapers = [
          (cosmicLib.cosmic.mkRON "tuple" [
            "Virtual-1"
            (cosmicLib.cosmic.mkRON "enum" {
              value = [
                "/per/etc/nixos/home/wallpapers/appa.jpg"
              ];
              variant = "Path";
            })
          ])
        ];
      };
      version = 1;
    };
  };
}
