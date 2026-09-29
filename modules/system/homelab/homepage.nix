{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.homepage;
  hl = config.modules.system.homelab;
  inherit (lib) mkIf;

  # Build services YAML from enabled homelab services
  # Remote wake for the gaming PC lives on the router, not here:
  # Fritz!Box Heimnetz → computer → "Computer starten" (or MyFRITZ!App
  # when off-LAN). The Moonlight / Steam Link apps handle wake + presence
  # on the LAN themselves. The Fritz!Box card under Network links there.
  infraServices = [
    {
      "M920q" = {
        icon = "mdi-server";
        href = "http://192.168.178.2:${toString hl.monitoring.grafanaPort}";
        description = "Homelab Server";
      };
    }
  ];

  mediaServices =
    lib.optionals hl.immich.enable [
      {
        "Immich" = {
          icon = "mdi-photo";
          href = "https://${hl.caddyProxy.tailnetDomain}";
          description = "Photo Management";
        };
      }
    ]
    ++ lib.optionals hl.navidrome.enable [
      {
        "Navidrome" = {
          icon = "mdi-music";
          href = "https://${hl.caddyProxy.tailnetDomain}/navidrome";
          description = "Music Streaming";
        };
      }
    ]
    ++ lib.optionals hl.jellyfin.enable [
      {
        "Jellyfin" = {
          icon = "mdi-filmstrip";
          # Served directly on the LAN/tailnet port. Jellyfin client apps
          # expect to be reached at the server root, so it is not path-routed
          # through Caddy like the other services.
          href = "http://192.168.178.2:8096";
          description = "Movies & Series";
        };
      }
    ];

  monitoringServices = lib.optionals hl.monitoring.enable [
    {
      "Grafana" = {
        icon = "mdi-chart-line";
        href = "https://${hl.caddyProxy.tailnetDomain}/grafana";
        description = "Dashboards";
      };
    }
    {
      "Prometheus" = {
        icon = "mdi-database";
        href = "http://192.168.178.2:${toString hl.monitoring.prometheusPort}";
        description = "Metrics";
      };
    }
  ];

  networkServices =
    lib.optionals hl.adguardhome.enable [
      {
        "AdGuard Home" = {
          icon = "mdi-shield";
          href = "https://${hl.caddyProxy.tailnetDomain}/adguard";
          description = "DNS";
        };
      }
    ]
    ++ [
      {
        "Fritz!Box" = {
          icon = "mdi-router-wireless";
          href = "http://192.168.178.1";
          description = "Router";
        };
      }
    ];

  systemServices =
    lib.optionals hl.nextcloud.enable [
      {
        "Nextcloud" = {
          icon = "mdi-cloud";
          href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud";
          description = "File Sync";
        };
      }
    ]
    ++ lib.optionals hl.ntfy.enable [
      {
        "ntfy.sh" = {
          icon = "mdi-bell";
          href = "http://192.168.178.2:2586";
          description = "Push Notifications";
        };
      }
    ]
    ++ lib.optionals hl.zellijWeb.enable [
      {
        "Zellij Web" = {
          icon = "mdi-console";
          # Tailscale Serve endpoint (TLS, tailnet-only). The server binds
          # loopback only, so the LAN IP is unreachable.
          href = "https://${hl.zellijWeb.tailnetDomain}:${toString hl.zellijWeb.httpsPort}";
          description = "Terminal";
        };
      }
    ]
    ++ lib.optionals hl.opencodeWeb.enable [
      {
        "OpenCode" = {
          icon = "mdi-robot";
          href = "https://${hl.opencodeWeb.tailnetDomain}:${toString hl.opencodeWeb.httpsPort}";
          description = "AI Agent";
        };
      }
    ];

  # Emergency access to Intel AMT. Convenience links only: the dashboard
  # runs on the m920q itself, so with the host down these vanish and the
  # phone's pinned browser bookmarks (AMT over IPv4 and IPv6) are the
  # authoritative path. Power control is deliberately not a card - the HTTP
  # relay was removed on purpose and the phone issues
  # "ssh m920q desktop-power on|off|status" from a termux widget instead.
  rescueServices = [
    {
      "AMT (IPv4)" = {
        icon = "mdi-chip";
        href = "https://116.204.198.109:16993";
        description = "Intel AMT via FRITZ!Box, works from any vantage";
        # The light covers the host-side AMT chain (DNAT -> socat -> LMS ->
        # ME), the only part a local dashboard can probe: the ME demands
        # unsafe TLS renegotiation that Node's TLS stack refuses, so the WAN
        # WS-Man endpoint is unmonitorable from here. The Fritz rule plus
        # ME TLS end to end is verified from outside (check-host) instead.
        siteMonitor = "http://192.168.178.10:16992/";
      };
    }
    {
      "AMT (IPv6)" = {
        icon = "mdi-chip";
        href = "https://[2a02:1748:dd4d:9990::10]:16993";
        description = "Intel AMT direct, outside the home LAN only";
      };
    }
  ];

  allServices =
    lib.optionals (rescueServices != []) [{"Rescue" = rescueServices;}]
    ++ lib.optionals (infraServices != []) [{"Infrastructure" = infraServices;}]
    ++ lib.optionals (mediaServices != []) [{"Media" = mediaServices;}]
    ++ lib.optionals (monitoringServices != []) [{"Monitoring" = monitoringServices;}]
    ++ lib.optionals (networkServices != []) [{"Network" = networkServices;}]
    ++ lib.optionals (systemServices != []) [{"System" = systemServices;}];
in {
  options.modules.system.homelab.homepage = {
    enable = lib.mkEnableOption "Homepage dashboard — live service status overview";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3002;
      description = "Homepage dashboard HTTP port";
    };
  };

  config = mkIf cfg.enable {
    # The upstream NixOS module sets DynamicUser=true, which creates a
    # private-namespace bind mount at /var/lib/homepage-dashboard. This
    # conflicts with impermanence's bind mount at that path and the
    # transient uid it creates cannot write to directories it doesn't own.
    # A static user sidesteps both problems, matching the pattern used by
    # adguardhome.nix.
    users.users.homepage-dashboard = {
      isSystemUser = true;
      group = "homepage-dashboard";
    };
    users.groups.homepage-dashboard = {};

    systemd.services.homepage-dashboard.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "homepage-dashboard";
      Group = lib.mkForce "homepage-dashboard";
    };

    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.port;
      # Caddy terminates TLS for the tailnet domain and proxies with the
      # original Host header, so Homepage must allow it. Without this every
      # tailnet request fails with HTTP 400 "Host validation failed" while
      # localhost still works. Local entries preserve direct loopback checks.
      allowedHosts = lib.concatStringsSep "," (
        lib.optionals hl.caddyProxy.enable [hl.caddyProxy.tailnetDomain]
        ++ [
          "localhost:${toString cfg.port}"
          "127.0.0.1:${toString cfg.port}"
        ]
      );
      services = allServices;
      settings = {
        title = "Homelab";
        headerStyle = "clean";
        theme = "dark";
        color = "slate";
      };
      bookmarks = [
        {
          "Quick Links" = [
            {
              "Grafana" = [
                {
                  icon = "mdi-chart-line";
                  href = "https://${hl.caddyProxy.tailnetDomain}/grafana";
                }
              ];
            }
            {
              "Nextcloud" = [
                {
                  icon = "mdi-cloud";
                  href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud";
                }
              ];
            }
          ];
        }
      ];
    };

    networking.firewall.allowedTCPPorts = mkIf (!hl.caddyProxy.enable) [
      cfg.port
    ];

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/homepage-dashboard";
        user = "homepage-dashboard";
        group = "homepage-dashboard";
        mode = "0700";
      }
    ];
  };
}
