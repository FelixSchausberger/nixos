{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.moonshine;
in {
  options.modules.system.moonshine = {
    enable = lib.mkEnableOption "Moonshine game streaming server (Moonlight protocol)";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hostConfig.user or "schausberger";
      description = "User to run Moonshine as";
    };

    uid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = config.users.users.${cfg.user}.uid or null;
      defaultText = lib.literalExpression "config.users.users.<user>.uid";
      description = "User UID for Moonshine runtime directory";
    };
  };

  config = lib.mkIf cfg.enable {
    services.moonshine = {
      enable = true;
      inherit (cfg) user;
      inherit (cfg) uid;

      openFirewall = true;

      settings = {
        name = "Moonshine";
        application = [
          {
            title = "Steam";
            command = [
              "/run/current-system/sw/bin/steam"
              "steam://open/bigpicture"
            ];
          }
        ];
      };
    };
  };
}
