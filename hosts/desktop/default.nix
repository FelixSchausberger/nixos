{inputs, ...}: let
  hostLib = import ../lib.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hosts.${hostName};
  # Only import WMs that are in the main config, not specialisation WMs
  # This prevents eager evaluation of all WM modules
in {
  imports =
    [
      ./disko.nix
      ./base-config.nix
      ../../modules/system/specialisations.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    inherit (hostInfo) wms;
    # user and system use defaults from lib/defaults.nix

    # Define specialisations for this host
    # Parent config provides hyprland as default, specialisations provide alternative WMs
    specialisations = {
      # Niri specialisation
      niri = {
        wms = ["niri"];
        profile = "default";
        extraConfig = {
          home-manager.users.${inputs.self.lib.user}.imports = [
            inputs.niri.homeModules.config
            ../../modules/home/wm/niri
            ../../home/profiles/desktop/niri.nix.specialisation
          ];
        };
      };

      # GNOME specialisation
      gnome = {
        wms = ["gnome"];
        profile = "default";
        extraConfig = {};
      };
    };
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
