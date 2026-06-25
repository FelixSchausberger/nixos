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
          "server min protocol" = "SMB2_02";
          "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=262144 SO_SNDBUF=262144";
          "read raw" = "yes";
          "write raw" = "yes";
          "oplocks" = "yes";
          # ZFS doesn't implement kernel oplocks — disabling prevents EBUSY
          "kernel oplocks" = "no";
          "max xmit" = "65535";
          "getwd cache" = "yes";
          "aio read size" = "1048576";
          "aio write size" = "1048576";
          "min receivefile size" = "16384";
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
          "force group" = "sambashare";
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
      after = ["samba-smbd.service"];
      requires = ["samba-smbd.service"];
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

    systemd.tmpfiles.rules = let
      inherit (config.modules.system.homelab.samba) dataPath;
    in [
      "d ${dataPath} 0775 root sambashare -"
      # Allow sambashare group full access + default ACL for new files
      "a+ ${dataPath} - - - - g:sambashare:rwx,d:g:sambashare:rwx"
      # Same ACLs on the Obsidian vault and Documents (Nextcloud-exposed dirs)
      "a+ ${dataPath}/Obsidian - - - - g:sambashare:rwx,d:g:sambashare:rwx"
      "a+ ${dataPath}/Documents - - - - g:sambashare:rwx,d:g:sambashare:rwx"
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
