{
  config,
  lib,
  ...
}: let
  cfg = config.wm.niri;
in {
  config = lib.mkIf cfg.enable {
    # Walker is enabled via shared walker module (imported in shared-imports.nix)
    # Niri window switching not available in walker (no native niri module)
  };
}
