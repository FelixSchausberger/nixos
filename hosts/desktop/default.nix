{inputs, ...}: let
  hostLib = import ../lib.nix;
  hostName = "desktop";
  hostInfo = inputs.self.lib.hosts.${hostName};
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
    # Performance profiles handled via runtime systemd targets (see performance-runtime.nix)
    specialisations = {
      # Niri specialisation
      niri = {
        wms = ["niri"];
        profile = "default";
        extraConfig = {
          imports = [../../modules/system/wm/niri.nix];
          home-manager.users.${inputs.self.lib.user}.imports = [
            ../../modules/home/wm/niri
            ../../home/profiles/desktop/niri.nix.specialisation
          ];
        };
      };

      # GNOME specialisation
      gnome = {
        wms = ["gnome"];
        profile = "default";
        extraConfig = {
          imports = [../../modules/system/wm/gnome.nix];
        };
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
