{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.jellyfin;
  inherit
    (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
in {
  options.modules.system.homelab.jellyfin = {
    enable = mkEnableOption "Jellyfin media server";

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the default Jellyfin HTTP/HTTPS ports (8096/8920) in the firewall";
    };

    maxConcurrentStreams = mkOption {
      type = types.nullOr types.ints.positive;
      default = 3;
      description = ''
        Cap on concurrent transcodes. Bounds CPU and GPU use on the 16 GB host,
        whose memory is shared with Immich, Nextcloud and the ZFS ARC.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      inherit (cfg) openFirewall;

      # UHD 630 (Gen9.5) Quick Sync: h264/hevc decode+encode, vp9 decode.
      hardwareAcceleration = {
        enable = true;
        type = "qsv";
        device = "/dev/dri/renderD128";
      };

      # NixOS is the single source of truth for encoding settings; edits made
      # in the web UI are deliberately overwritten on the next restart.
      forceEncodingConfig = true;

      transcoding = {
        enableHardwareEncoding = true;
        inherit (cfg) maxConcurrentStreams;
      };
    };

    # The render node is root-owned; the service user needs it for Quick Sync.
    users.users.jellyfin.extraGroups = ["render" "video"];

    systemd.services.jellyfin.serviceConfig = {
      MemoryMax = "3G";
      MemoryHigh = "2500M";
      CPUQuota = "300%";
    };

    # Config, metadata and transcoding scratch live in /var/lib/jellyfin, which
    # is persisted to /per (NVMe rpool). The media library itself stays on the
    # SMR SATA dpool, where only sequential reads occur.
    environment.persistence."/per".directories = [
      "/var/lib/jellyfin"
    ];
  };
}
