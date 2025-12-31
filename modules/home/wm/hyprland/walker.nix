{
  config,
  lib,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  config = lib.mkIf cfg.enable {
    # Walker is enabled via shared walker module (imported in shared-imports.nix)
    # Hyprland-specific window switching module is auto-detected by shared/walker.nix
  };
}
