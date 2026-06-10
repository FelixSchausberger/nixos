# Self-hosted ntfy.sh push notification server.
# Delivers alerts from Grafana, smartd, ZED, and health checks to the ntfy phone app.
{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.ntfy;
  inherit (lib) mkIf mkEnableOption;
in {
  options.modules.system.homelab.ntfy = {
    enable = mkEnableOption "ntfy.sh push notification server";
  };

  config = mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;

      settings = {
        base-url = "http://m920q:2586";
        listen-http = "0.0.0.0:2586";

        auth-file = "/per/var/lib/ntfy-sh/user.db";
        cache-file = "/per/var/lib/ntfy-sh/cache-file.db";
        attachment-cache-dir = "/per/var/lib/ntfy-sh/attachments";

        auth-default-access = "read-write";
      };
    };

    systemd.services.ntfy-sh = {
      # Override default service settings that conflict with impermanence
      # DynamicUser + StateDirectory tries to migrate /var/lib/ntfy-sh to
      # /var/lib/private/ntfy-sh but fails because /var/lib/ntfy-sh is a bind mount.
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        StateDirectory = lib.mkForce null;
        User = lib.mkForce "ntfy-sh";
        Group = lib.mkForce "ntfy-sh";
      };
    };

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/ntfy-sh";
        user = "ntfy-sh";
        group = "ntfy-sh";
        mode = "0700";
      }
    ];

    networking.firewall.allowedTCPPorts = [
      2586
    ];
  };
}
