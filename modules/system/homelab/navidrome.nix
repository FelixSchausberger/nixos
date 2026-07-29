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

    # Navidrome runs as its own system user; must be able to read the music library
    users.users.navidrome.extraGroups = ["users"];

    environment.persistence."/per".directories = [
      "/var/lib/navidrome"
    ];
  };
}
