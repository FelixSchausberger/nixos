# System-side COSMIC session module wired into shared UWSM session management.
# Activates only when hostConfig selects COSMIC on GUI-capable hosts.
{
  pkgs,
  lib,
  hostConfig,
  ...
}: let
  # nixpkgs has no package for this applet and nixos-cosmic's copy tracks a
  # 2025 source, so build the active upstream locally.
  clipboardApplet = pkgs.callPackage ../../../pkgs/cosmic-ext-applet-clipboard-manager {};
in {
  imports = [
    ../session/default.nix
    ../session/cosmic.nix
  ];

  config = lib.mkIf (hostConfig.isGui && builtins.elem "cosmic" hostConfig.wms) {
    services = {
      desktopManager.cosmic.enable = true;
      # Display manager configuration moved to unified display-manager.nix
    };

    xdg.portal = {
      enable = true;
      config.common.default = "*";
      extraPortals = [pkgs.xdg-desktop-portal-cosmic];
    };

    environment = {
      cosmic.excludePackages = with pkgs;
        [
          cosmic-wallpapers
        ]
        ++ (lib.optional (
            pkgs.kdePackages ? xwaylandvideobridge
          )
          pkgs.kdePackages.xwaylandvideobridge);

      persistence."/per" = {
        users.${hostConfig.user} = {
          directories = [
            {
              directory = ".config/cosmic/";
            }
          ];
        };
      };

      sessionVariables = {
        # For the clipboard manager to work zwlr_data_control_manager_v1 protocol needs to be available
        COSMIC_DATA_CONTROL_ENABLED = 1;

        # Firefox fullscreen freezes cosmic
        # Remove once https://github.com/pop-os/cosmic-comp/issues/713 is fixed
        COSMIC_DISABLE_DIRECT_SCANOUT = 1;
      };

      systemPackages = with pkgs; [
        clipboardApplet
        cosmic-ext-applet-caffeine # Prevents your screen from going to sleep
        cosmic-ext-applet-external-monitor-brightness # Change brightness of external monitors via DDC/CI protocol.

        xdg-desktop-portal-wlr
      ];
    };
  };
}
