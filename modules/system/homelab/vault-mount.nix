{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.vaultMount;
  defaults = inputs.self.lib.defaults;
  user = defaults.system.user;

  # Credentials arrive through the sops-rendered env file (sops-nix writes
  # it 0400 for the mounting user); the app password never enters the nix
  # store. rclone reads the backend entirely from RCLONE_CONFIG_<name> env.
  # The mount runs in the foreground so journald owns the log; on failure
  # the unit retries every 10s against a Nextcloud that may still be
  # starting. Writes land through vfs-cache with a short write-back so a
  # saved note reaches the server without waiting for an editor exit.
  vaultMountScript = pkgs.writeShellScript "vault-mount" ''
    export RCLONE_CONFIG_VAULT_TYPE=webdav
    export RCLONE_CONFIG_VAULT_URL=${cfg.url}
    export RCLONE_CONFIG_VAULT_VENDOR=nextcloud
    export RCLONE_CONFIG_VAULT_USER=${cfg.user}
    export RCLONE_CONFIG_VAULT_PASS=$(${pkgs.rclone}/bin/rclone obscure "$VAULT_APP_PASSWORD")
    exec ${pkgs.rclone}/bin/rclone mount vault: ${cfg.mountPath} \
      --vfs-cache-mode writes \
      --vfs-write-back 10s \
      --dir-cache-time 60s
  '';

  mountPrep = pkgs.writeShellScript "vault-mount-prep" ''
    mkdir -p ${cfg.mountPath}
    # Clear a stale fuse mount from a crashed unit so the new one binds.
    ${pkgs.fuse3}/bin/fusermount3 -uz ${cfg.mountPath} 2>/dev/null || true
  '';
in {
  options.modules.system.homelab.vaultMount = {
    enable = lib.mkEnableOption "WebDAV mount of the Nextcloud vault for terminal tooling";

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8081/remote.php/dav/files/admin/Obsidian";
      # Remote TUI hosts enter the tailnet Caddy address instead:
      # https://m920q.tailf2f0ca.ts.net/nextcloud/remote.php/dav/files/admin/Obsidian
      description = "WebDAV URL of the Obsidian external storage mount";
    };

    mountPath = lib.mkOption {
      type = lib.types.str;
      # The mount point stays clear of the Nextcloud external-storage
      # directory (/per/mnt/data/notes): tools must never see both paths.
      default = "${defaults.paths.homeDir}/notes";
      description = "Vault mount point for terminal tooling";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = user;
      description = "Account that owns the mount and its credentials";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."nextcloud/vault-app-password" = {};

    sops.templates."vault-mount/env" = {
      content = ''
        VAULT_APP_PASSWORD=${config.sops.placeholder."nextcloud/vault-app-password"}
      '';
      owner = cfg.user;
      path = "/run/secrets/vault-mount/env";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.mountPath} 0755 ${cfg.user} users -"
    ];

    # The pointed-to path must stay exclusive: tools that reach the vault do
    # so through the mount, and everyone else through the Nextcloud API.
    # The TUI tooling path override lands with this enable.
    home-manager.users.${cfg.user} = {
      modules.home.tui.vault.path = cfg.mountPath;
    };

    systemd.services.vault-mount = {
      description = "WebDAV mount of the Nextcloud vault for terminal tooling";
      # nginx serves the local Nextcloud front door on the loopback url.
      after = ["nginx.service" "network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = "users";
        EnvironmentFile = config.sops.templates."vault-mount/env".path;
        ExecStartPre = mountPrep;
        ExecStart = "${vaultMountScript}";
        ExecStopPost = "${pkgs.fuse3}/bin/fusermount3 -uz ${cfg.mountPath}";
        Restart = "on-failure";
        RestartSec = "10s";
        Nice = 5;
        IOSchedulingClass = "idle";
      };
    };
  };
}
