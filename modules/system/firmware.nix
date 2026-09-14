# Firmware updates via fwupd.
#
# A separate concern from any compositor or desktop: keeping firmware current is
# a hardware-management task, so hosts opt in explicitly rather than inheriting
# it from a window-manager module.
{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.firmware;
in {
  options.modules.system.firmware = {
    enable = lib.mkEnableOption "fwupd firmware update daemon";
  };

  config = lib.mkIf cfg.enable {
    services.fwupd.enable = true;
  };
}
