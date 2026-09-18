{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.navidrome;
  inherit
    (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
in {
  options.modules.system.homelab.navidrome = {
    enable = mkEnableOption "Navidrome music streaming server";

    musicFolder = mkOption {
      type = types.str;
      default = "/per/mnt/data/Media/Music";
      description = "Path to music library for Navidrome to scan";
    };

    port = mkOption {
      type = types.port;
      default = 4533;
      description = "HTTP port for Navidrome web UI and Subsonic API";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall for Navidrome HTTP port";
    };
  };

  config = mkIf cfg.enable {
    services.navidrome = {
      enable = true;
      inherit (cfg) openFirewall;
      settings = {
        Address = "0.0.0.0";
        Port = cfg.port;
        MusicFolder = cfg.musicFolder;
        EnableInsightsCollector = false;
        EnableDownloads = true;
        AutoImportPlaylists = false;
        ScanSchedule = "@every 30m";
        TranscodingCacheSize = "100MB";
        DefaultTranscodingBitrate = "128";
      };
    };

    # Navidrome reads the library as its own system user, which is neither the
    # file owner nor (historically) in the owner's group, so a track imported
    # with restrictive modes (0740 schausberger:schausberger) fails every play
    # with "permission denied". Two layers keep the library readable:
    #   - group schausberger covers files that arrive group-readable (the
    #     historical import mode) and moved-in files, which keep their own
    #     modes and do not inherit the ACL below;
    #   - the tmpfiles ACL grants navidrome read on the library root and, via
    #     the default ACL, on everything created under it (same pattern as the
    #     samba module). Import new music with group/other-readable modes (plain
    #     `cp`, or chmod -R g+rX after rsync -a); if the library is recreated,
    #     `setfacl -R -m u:navidrome:rX,d:u:navidrome:rX <library>` restores
    #     access without a rebuild.
    users.users.navidrome.extraGroups = ["users" "schausberger"];

    systemd.tmpfiles.rules = [
      "a+ ${cfg.musicFolder} - - - - u:navidrome:rX,d:u:navidrome:rX"
    ];

    environment.persistence."/per".directories = [
      "/var/lib/navidrome"
    ];
  };
}
