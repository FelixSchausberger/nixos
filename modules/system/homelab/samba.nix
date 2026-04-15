{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  options.modules.system.homelab.samba = {
    enable = lib.mkEnableOption "Samba SMB/CIFS file sharing";
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/per/mnt/data";
      description = "Root path of the shared data directory";
    };
  };

  config = lib.mkIf config.modules.system.homelab.samba.enable {
    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "m920q NAS";
          "netbios name" = "m920q";
          "security" = "user";
          # Performance tuning for gigabit LAN
          "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
          "read raw" = "yes";
          "write raw" = "yes";
          "oplocks" = "yes";
          "max xmit" = "65535";
          "getwd cache" = "yes";
          # macOS compatibility
          "vfs objects" = "catia fruit streams_xattr";
          "fruit:metadata" = "stream";
          "fruit:posix_rename" = "yes";
          "fruit:veto_appledouble" = "no";
          "fruit:delete_empty_adfiles" = "yes";
        };
        data = {
          "path" = config.modules.system.homelab.samba.dataPath;
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "valid users" = "@sambashare";
          "vfs objects" = "catia fruit streams_xattr recycle";
          "recycle:repository" = ".recycle";
          "recycle:keeptree" = "yes";
          "recycle:versions" = "yes";
        };
      };
    };

    # Set Samba password from sops secret on each boot
    sops.secrets."samba/user-password" = {
      owner = "root";
    };

    systemd.services.samba-setpasswd = {
      description = "Set Samba password for ${defaults.system.user} from sops secret";
      wantedBy = ["multi-user.target"];
      after = ["samba.service"];
      requires = ["samba.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "samba-setpasswd" ''
          password=$(cat ${config.sops.secrets."samba/user-password".path})
          echo -e "$password\n$password" | ${pkgs.samba}/bin/smbpasswd -s -a ${defaults.system.user}
        '';
      };
    };

    users.groups.sambashare = {};
    users.users.${defaults.system.user}.extraGroups = ["sambashare"];

    systemd.tmpfiles.rules = [
      "d ${config.modules.system.homelab.samba.dataPath} 0775 root sambashare -"
    ];

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/samba";
        user = "root";
        group = "root";
        mode = "0755";
      }
    ];
  };
}
