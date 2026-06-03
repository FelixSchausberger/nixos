{
  config,
  lib,
  hostConfig,
  ...
}: let
  cfg = config.modules.system.sunshine;
in {
  options.modules.system.sunshine = {
    enable = lib.mkEnableOption "Sunshine game streaming server";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hostConfig.wms != [];
        message = "modules.system.sunshine.enable requires a graphical session (hostConfig.wms must be non-empty)";
      }
      {
        assertion = hostConfig.isGui;
        message = "modules.system.sunshine.enable requires hostConfig.isGui = true";
      }
    ];

    services.sunshine = {
      enable = true;
      openFirewall = true;
      # CAP_SYS_ADMIN required for virtual input (keyboard/mouse capture)
      capSysAdmin = true;
      # wlr capture mode for Hyprland headless display support
      settings = {
        capture = "wlr";
        output_name = "VIRTUAL-1";
      };
    };

    # uinput kernel module and udev rule for keyboard/mouse forwarding
    boot.kernelModules = ["uinput"];
    services.udev.extraRules = ''
      KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    '';
  };
}
