{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.immich;
in {
  options.modules.system.homelab.immich = {
    enable = lib.mkEnableOption "Immich photo backup server";
    openFirewall = lib.mkEnableOption "open firewall port for direct access (no reverse proxy)";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data/immich";
      description = "Path for Immich media library";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "HTTP port for Immich web UI";
    };
  };

  config = lib.mkIf cfg.enable {
    services.immich = {
      enable = true;
      host =
        if cfg.openFirewall
        then "0.0.0.0"
        else "127.0.0.1";
      inherit (cfg) port;
      mediaLocation = cfg.dataPath;
      inherit (cfg) openFirewall;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0700 immich immich -"
    ];

    environment.persistence."/per".directories = [
      "/var/lib/immich"
    ];
  };
}
