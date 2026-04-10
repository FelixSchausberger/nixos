{
  config,
  lib,
  ...
}: {
  options.modules.system.homelab.immich = {
    enable = lib.mkEnableOption "Immich photo backup server";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data/immich";
      description = "Path for Immich media library";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "HTTP port for Immich web UI (accessed via Caddy reverse proxy)";
    };
  };

  config = lib.mkIf config.modules.system.homelab.immich.enable {
    services.immich = {
      enable = true;
      host = "127.0.0.1";
      inherit (config.modules.system.homelab.immich) port;
      mediaLocation = config.modules.system.homelab.immich.dataPath;
      # Not exposed directly — access via Caddy reverse proxy only
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d ${config.modules.system.homelab.immich.dataPath} 0700 immich immich -"
    ];

    environment.persistence."/per".directories = [
      "/var/lib/immich"
    ];
  };
}
