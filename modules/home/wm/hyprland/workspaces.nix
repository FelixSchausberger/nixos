{
  config,
  lib,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Dynamic workspace configuration - no persistent workspaces
      workspace = [];

      # Minimal window rules for floating and pinning
      windowrulev2 = [
        # Pin important floating windows
        "pin,class:^(floating-mode)$"
        "pin,class:^(it.mijorus.smile)$"
        "pin,title:^(Picture-in-Picture)$"

        # Float specific utility windows
        "float,class:^(floating-mode)$"
        "float,class:^(it.mijorus.smile)$"
        "float,class:^(org.gnome.Calculator)$"
      ];

      # Dynamic workspace behavior - keeping only essential bindings
      bind = [];
    };

    # Dynamic workspace utilities (minimal)
    home.packages = [];
  };
}
