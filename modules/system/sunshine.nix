{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.sunshine;
in {
  options.modules.system.sunshine = {
    enable = lib.mkEnableOption "Sunshine game streaming server";
  };

  config = lib.mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      openFirewall = true;
      # CAP_SYS_ADMIN required for virtual input (keyboard/mouse capture)
      capSysAdmin = true;
    };

    # uinput kernel module and udev rule for keyboard/mouse forwarding
    boot.kernelModules = ["uinput"];
    services.udev.extraRules = ''
      KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    '';
  };
}
