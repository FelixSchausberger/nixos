# Music Assistant server: streams the Navidrome (Subsonic API) library,
# streaming services and radio to the network players. The sink here is the
# living-room NAD C 368 (MDC BluOS 2i module, on the WLAN) via MA's native
# Bluesound player provider; Home Assistant embeds the players and Zigbee
# buttons can drive them through automations.
#
# Two configuration steps are UI-deliberate by design, not config drift:
#   - music providers (opensubsonic pointing at the local Navidrome, the
#     auto-discovered amp) are added in the Music Assistant web client;
#   - the Home Assistant integration ships in HA core and signs in with an
#     MA admin account, because play_media resolves the acting user and
#     permission-errors for non-admins later.
{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.musicAssistant;
in {
  options.modules.system.homelab.musicAssistant = {
    enable = lib.mkEnableOption "Music Assistant music streaming server";

    providers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["bluesound" "opensubsonic"];
      # bluesound = player provider for the BluOS-based amp; opensubsonic =
      # source provider for the Navidrome on this host.
      description = ''
        Music Assistant provider dependencies to install. The names must
        match the nixpkgs services.music-assistant.providers enum.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.music-assistant = {
      enable = true;
      inherit (cfg) providers;
      # The nixpkgs module opens TCP 8097 on this flag: the stream port the
      # players pull audio from on the LAN. MA controls the player fine
      # without it, but playback stalls silently. The 8095 API/client port
      # stays behind the firewall on purpose: the server is reached through
      # the HA frontend, not the LAN.
      openFirewall = true;
    };

    # Player discovery is mDNS based. Outbound requests to the amp need no
    # firewall change; the inbound UDP 5353 listener on this host exists
    # through the airplay receiver module's avahi openFirewall. If that
    # module ever leaves m920q, allow 5353 under networking.firewall here.

    # MA spawns per-provider python workers and on-demand transcoders, so
    # RSS jumps are normal but uncapped; the same runaway protection as the
    # HA and jellyfin services keeps a scan surge from evicting immich on
    # the 16 GB host.
    systemd.services.music-assistant.serviceConfig = {
      MemoryMax = "1200M";
      MemoryHigh = "1000M";
    };

    # State survives reboots on the impermanence host; the tmpfiles rule
    # creates the directory under the mount source directly so the ordering
    # against the impermanence bind mounts cannot shadow it (same
    # workaround as smart-home.nix). The nixpkgs unit runs as a DynamicUser
    # with StateDirectory, so the store directory stays root-owned here and
    # systemd re-owns it on every unit start.
    systemd.tmpfiles.rules = [
      "d /per/var/lib/music-assistant 0755 root root -"
    ];

    environment.persistence."/per".directories = [
      {directory = "/var/lib/music-assistant";}
    ];
  };
}
