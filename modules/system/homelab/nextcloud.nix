{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.system.homelab.nextcloud;
in
{
  options.modules.system.homelab.nextcloud = {
    enable = lib.mkEnableOption "Nextcloud file sync and share server";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data/nextcloud";
      description = "Path for Nextcloud data directory";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "HTTP port for Nextcloud web UI";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for Nextcloud server";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Nextcloud HTTP port";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      enable = true;
      hostName = "nextcloud.local";
      package = pkgs.nextcloud33;
      config = {
        dbtype = "pgsql";
        adminuser = "admin";
        adminpassFile = config.sops.secrets."nextcloud/admin-password".path;
      };
      settings = {
        trusted_domains = [
          "nextcloud.local"
          "localhost"
          "127.0.0.1"
          "192.168.178.2"
          "100.105.37.12"
        ];
      };
      maxUploadSize = "16G";
      https = false;
      configureRedis = true;
      autoUpdateApps.enable = true;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "nextcloud" ];
      ensureUsers = [
        {
          name = "nextcloud";
          ensureDBOwnership = true;
        }
      ];
      authentication = ''
        local all nextcloud trust
        host all nextcloud 127.0.0.1/32 trust
        host all nextcloud ::1/128 trust
        local all all ident
        host all all 127.0.0.1/32 ident
      '';
    };

    services.nginx = {
      enable = true;
      virtualHosts."nextcloud.local" = {
        listen = [
          {
            addr = cfg.host;
            port = cfg.port;
          }
        ];
      };
    };

    sops.secrets."nextcloud/admin-password" = {
      owner = "nextcloud";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0750 nextcloud nextcloud -"
      "d ${cfg.dataPath}/config 0750 nextcloud nextcloud -"
      "d ${cfg.dataPath}/data 0750 nextcloud nextcloud -"
    ];

    services.nextcloud.datadir = cfg.dataPath;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    environment.persistence."/per".directories = [
      "/var/lib/nextcloud"
      "/var/lib/nginx"
      "/var/lib/postgresql"
    ];
  };
}
