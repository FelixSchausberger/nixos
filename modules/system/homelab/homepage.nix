{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.homepage;
  hl = config.modules.system.homelab;
  inherit (lib) mkIf;

  # Build services YAML from enabled homelab services
  infraServices =
    [
      {
        "M920q" = {
          icon = "mdi-server";
          href = "http://192.168.178.2:${toString hl.monitoring.grafanaPort}";
          description = "Homelab Server";
        };
      }
    ]
    ++ lib.optionals hl.remoteControl.enable [
      {
        "Desktop" = {
          icon = "mdi-desktop-tower";
          href = "http://${hl.remoteControl.desktopIp}";
          description = "Desktop Workstation";
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
    ++ lib.optionals hl.remoteControl.enable [
      {
        "Remote Control" = {
          icon = "mdi-remote";
          href = "https://${hl.caddyProxy.tailnetDomain}/remote-control";
          description = "Device Control";
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

  allServices =
    lib.optionals (infraServices != []) [{"Infrastructure" = infraServices;}]
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
