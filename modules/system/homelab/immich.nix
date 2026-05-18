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
      description = "HTTP port for Immich web UI";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for Immich server";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Immich HTTP port";
    };
  };

  config = lib.mkIf config.modules.system.homelab.immich.enable {
    services.immich = {
      enable = true;
      host = config.modules.system.homelab.immich.host;
      inherit (config.modules.system.homelab.immich) port;
      mediaLocation = config.modules.system.homelab.immich.dataPath;
      openFirewall = config.modules.system.homelab.immich.openFirewall;
    };

    systemd.tmpfiles.rules = [
      "d ${config.modules.system.homelab.immich.dataPath} 0700 immich immich -"
      "d ${config.modules.system.homelab.immich.dataPath}/backups 0700 immich immich -"
      "d ${config.modules.system.homelab.immich.dataPath}/encoded-video 0700 immich immich -"
      "d ${config.modules.system.homelab.immich.dataPath}/library 0700 immich immich -"
      "d ${config.modules.system.homelab.immich.dataPath}/profile 0700 immich immich -"
      "d ${config.modules.system.homelab.immich.dataPath}/thumbs 0700 immich immich -"
      "d ${config.modules.system.homelab.immich.dataPath}/upload 0700 immich immich -"
      "f ${config.modules.system.homelab.immich.dataPath}/backups/.immich 0600 immich immich - immich"
      "f ${config.modules.system.homelab.immich.dataPath}/encoded-video/.immich 0600 immich immich - immich"
      "f ${config.modules.system.homelab.immich.dataPath}/library/.immich 0600 immich immich - immich"
      "f ${config.modules.system.homelab.immich.dataPath}/profile/.immich 0600 immich immich - immich"
      "f ${config.modules.system.homelab.immich.dataPath}/thumbs/.immich 0600 immich immich - immich"
      "f ${config.modules.system.homelab.immich.dataPath}/upload/.immich 0600 immich immich - immich"
    ];

    environment.persistence."/per".directories = [
      "/var/lib/immich"
    ];
  };
}
