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
    # group schausberger is the fallback for library files that are only
    # group-readable (the historical import mode); the media-root ACL below
    # grants read directly. See navidrome.nix for the full permission model.
    users.users.jellyfin.extraGroups = ["render" "video" "schausberger"];

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

    # The upstream module's tmpfiles rules write to /var/lib/jellyfin, but the
    # impermanence bind mount is applied after systemd-tmpfiles-resetup during a
    # live switch, which shadows those subdirectories and leaves the persisted
    # dataset empty; jellyfin-pre-start then fails to write encoding.xml. Create
    # the directories under the mount source directly so the ordering does not
    # matter (the same workaround as modules/system/persistence-postgresql.nix).
    systemd.tmpfiles.rules = [
      "d /per/var/lib/jellyfin 0700 jellyfin jellyfin -"
      "d /per/var/lib/jellyfin/config 0700 jellyfin jellyfin -"
      "d /per/var/lib/jellyfin/log 0700 jellyfin jellyfin -"
      # Library read access. No libraries are configured yet; this is applied
      # now so the first library added does not hit the "permission denied"
      # failure the service user otherwise gets on restrictively-imported media.
      "a+ /per/mnt/data/Media - - - - u:jellyfin:rX,d:u:jellyfin:rX"
    ];
  };
}
