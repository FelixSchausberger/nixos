let
  hostLib = import ../lib.nix;
  wms = ["gnome" "hyprland" "niri"];
in {
  imports =
    [
      ../shared-gui.nix
      ./hardware-configuration.nix
    ]
    ++ hostLib.wmModules wms;

  # Host-specific configuration
  hostConfig = {
    hostName = "desktop";
    user = "schausberger";
    isGui = true; # Full desktop with GUI
    wm = wms;
    system = "x86_64-linux";
  };

  # Hardware configuration
  hardware = {
    # Desktop-specific hardware configuration
    keyboard.qmk.enable = true;

    # AMD RX 6700XT GPU configuration via profile
    profiles.amdGpu = {
      enable = true;
      variant = "desktop";
    };
  };

  # System maintenance and monitoring
  modules.system.maintenance = {
    enable = true;
    autoUpdate.enable = true;
    monitoring = {
      enable = true;
      alerts = true;
    };
  };
}
