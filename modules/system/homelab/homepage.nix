{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.homepage;
  hl = config.modules.system.homelab;
  inherit (lib) mkIf;

  tailscaleServe = import ../../../lib/tailscale-serve.nix {inherit pkgs;};

  # Loopback URL for probes. The dashboard runs on the m920q itself, so site
  # monitors and widgets reach services over 127.0.0.1 instead of going out
  # through the tailnet name the card links to. Probes are HTTP only: the
  # service runs with an empty CapabilityBoundingSet, which rules out the ICMP
  # that `ping:` would need, while siteMonitor is a HEAD request with a GET
  # fallback (405 from Navidrome therefore still reads as up).
  local = port: "http://127.0.0.1:${toString port}";

  # Ports with no module option behind them: jellyfin.nix follows the nixpkgs
  # default and ntfy.nix hardcodes its own listener, so each number is pinned
  # once here instead of repeated per URL.
  jellyfinPort = 8096;
  ntfyPort = 2586;

  # Crisp wallpaper the dashboard paints behind the cards. The name is an
  # option (default = the window manager's wallpaper) resolved against
  # lib/wallpapers.nix; caddy-proxy.nix serves the same file at /bg/<file>.
  # The *_blurred variant is deliberately not used: its soft frame exists for
  # the niri overview, not the dashboard.
  backgroundFile =
    inputs.self.lib.wallpapers.available.${cfg.backgroundWallpaper}
    or (throw "modules.system.homelab.homepage.backgroundWallpaper '${cfg.backgroundWallpaper}' is not in lib/wallpapers.nix (have: ${builtins.concatStringsSep ", " (builtins.attrNames inputs.self.lib.wallpapers.available)})");

  # The GitHub widgets read the existing sops github/token (the same secret the
  # git client and nix netrc use). It is declared by modules/system/sops-common.nix,
  # so presence is the gate rather than homepage.enable alone: a host without
  # sops has no token and the repository card is dropped instead of rendering a
  # placeholder that never resolves.
  githubAvailable = config.sops.secrets ? "github/token";
  githubHeaders = {
    Accept = "application/vnd.github+json";
    Authorization = "Bearer {{HOMEPAGE_VAR_GITHUB_TOKEN}}";
    User-Agent = "homepage";
  };

  # Host gauges for the Infrastructure cards. Each host's own node_exporter is
  # scraped into the local Prometheus (jobs "node" for m920q's loopback and
  # "node-desktop" for the gaming PC over the LAN), so one PromQL query per
  # block reads the same numbers the resources widget used to show locally.
  # A powered-off host returns an empty vector, so its blocks read "-" (the
  # desktop's graceful "off" state) and the desktop is intentionally excluded
  # from the NodeExporterDown rule.
  mkHostMetrics = host: [
    {
      label = "CPU";
      query = ''100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle",host="${host}"}[5m])))'';
      format = {
        type = "number";
        options.maximumFractionDigits = 0;
        suffix = "%";
      };
    }
    {
      label = "Memory";
      query = ''100 * (1 - node_memory_MemAvailable_bytes{host="${host}"} / node_memory_MemTotal_bytes{host="${host}"})'';
      format = {
        type = "number";
        options.maximumFractionDigits = 0;
        suffix = "%";
      };
    }
    {
      label = "Disk";
      # One mountpoint only: the widget renders the first series of the result,
      # so the pseudo-filesystem filter keeps the size floor meaningful.
      query = ''node_filesystem_avail_bytes{host="${host}",mountpoint="/",fstype!~"tmpfs|ramfs|squashfs|overlay|devtmpfs|efivarfs|iso9660|mqueue|hugetlbfs"}'';
      format.type = "bytes";
    }
    {
      label = "Uptime";
      query = ''time() - node_boot_time_seconds{host="${host}"}'';
      format.type = "duration";
    }
  ];

  # Composite health metrics per monitored host (journald + systemd + procfs,
  # not just the node_exporter gauges). m920q's daemon is scraped on loopback
  # (job "vitals"); the desktop runs no monitoring stack and publishes the same
  # series through its node exporter textfile collector (job "node-desktop").
  # Both carry a host label, so each card selects its own host's series.
  mkVitalsMetrics = host: [
    {
      label = "Score";
      query = ''vitals_health_score{host="${host}",type="smoothed"}'';
      format = {
        type = "number";
        options.maximumFractionDigits = 0;
      };
    }
    {
      label = "Errors";
      query = ''vitals_issues{host="${host}",severity="error"}'';
      format.type = "number";
    }
    {
      label = "Warnings";
      query = ''vitals_issues{host="${host}",severity="warning"}'';
      format.type = "number";
    }
    {
      label = "Load";
      query = ''vitals_load_average{host="${host}"}'';
      format = {
        type = "number";
        options.maximumFractionDigits = 2;
      };
    }
  ];

  # One widget per host folds the resource view and the health view into a
  # single card: prometheusmetric renders at most four blocks, so the card
  # carries CPU and memory from the node_exporter gauges plus the composite
  # health score and error count from vitals. Disk, uptime, warnings and load
  # stay in Grafana, which charts the same series the card reads; the Score
  # block is relabelled "Health" so it reads self-describing next to the
  # gauges.
  hostVitalsMetrics = host: let
    hostMetrics = mkHostMetrics host;
    vitalsMetrics = mkVitalsMetrics host;
  in [
    (builtins.elemAt hostMetrics 0)
    (builtins.elemAt hostMetrics 1)
    (builtins.elemAt vitalsMetrics 0 // {label = "Health";})
    (builtins.elemAt vitalsMetrics 1)
  ];

  hostVitalsWidget = host: {
    type = "prometheusmetric";
    url = local hl.monitoring.prometheusPort;
    refreshInterval = 30000;
    metrics = hostVitalsMetrics host;
  };

  # Build services YAML from enabled homelab services.
  #
  # One card per monitored host. The m920q's node_exporter answers on loopback
  # only and stands in for the host itself: if it stops answering, the
  # monitoring stack is blind, which is the condition this card reveals. The
  # desktop is a separate scrape job (an intentional power-off is not an
  # incident), so its card simply goes quiet when the PC sleeps.
  #
  # Remote wake for the gaming PC lives on the router, not here: Fritz!Box
  # Heimnetz → computer → "Computer starten" (or MyFRITZ!App when off-LAN). The
  # Moonlight / Steam Link apps handle wake + presence on the LAN themselves.
  # The Fritz!Box card under Router links there.
  #
  # Each card folds the resource gauges and the health view into one widget
  # (see hostVitalsMetrics); the deep-dive surface for both is the Grafana
  # dashboard charting the same series. m920q's card keeps a site monitor on
  # its node_exporter, whose silence would mean a blind monitoring stack,
  # while the desktop has none, because it is off most of the time and the
  # missing series already reads "-".
  infraServices = lib.optionals hl.monitoring.enable [
    {
      "M920q" = {
        icon = "mdi-server";
        href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/config-health";
        description = "Homelab server";
        siteMonitor = "${local hl.monitoring.nodeExporterPort}/metrics";
        widget = hostVitalsWidget config.networking.hostName;
      };
    }
    {
      "Desktop" = {
        icon = "mdi-desktop-tower";
        # No web UI runs on the gaming PC, and it is deliberately off most
        # of the time. A siteMonitor is a binary up/down dot that logs a
        # proxy error on every poll while it is off, and Homepage has no way
        # to show a neutral "off" state; the Prometheus widget below formats
        # a missing series as "-", so the card goes quiet instead of red.
        href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/config-health";
        description = "Gaming PC";
        widget = hostVitalsWidget "desktop";
      };
    }
  ];

  mediaServices =
    lib.optionals hl.immich.enable [
      {
        "Immich" = {
          icon = "immich.png";
          href = "https://${hl.caddyProxy.tailnetDomain}";
          description = "Photo Management";
          siteMonitor = local hl.immich.port;
          # Widget v2 against the installed Immich (>= v1.118); the sops
          # key grants server.statistics, all the widget reads.
          widget = {
            type = "immich";
            version = 2;
            url = local hl.immich.port;
            key = "{{HOMEPAGE_VAR_IMMICH_API_KEY}}";
          };
        };
      }
    ]
    ++ lib.optionals hl.navidrome.enable [
      {
        "Navidrome" = {
          icon = "navidrome.png";
          # The path route keeps the prefix (mkKeepRoute) and Navidrome
          # runs with BaseURL=/navidrome; stripping the prefix would make
          # its root-absolute redirects and API calls land on the Immich
          # catch-all instead of the music server.
          href = "https://${hl.caddyProxy.tailnetDomain}/navidrome";
          description = "Music Streaming";
          siteMonitor = local hl.navidrome.port;
          # Subsonic token auth: token = md5(password + salt) and Homepage
          # does no hashing, so the digest lives in sops while the salt
          # stays literal (useless on its own). BaseURL applies app-wide,
          # so loopback needs the /navidrome prefix as well.
          widget = {
            type = "navidrome";
            url = "${local hl.navidrome.port}/navidrome";
            user = "schausberger";
            token = "{{HOMEPAGE_VAR_NAVIDROME_TOKEN}}";
            salt = "hm2026nav";
          };
        };
      }
    ]
    ++ lib.optionals hl.jellyfin.enable [
      {
        "Jellyfin" = {
          icon = "jellyfin.png";
          # Served directly on the LAN/tailnet port. Jellyfin client apps
          # expect to be reached at the server root, so it is not path-routed
          # through Caddy like the other services.
          href = "http://192.168.178.2:${toString jellyfinPort}";
          description = "Movies & Series";
          siteMonitor = local jellyfinPort;
          # Widget v2: the docs map Jellyfin >= 12 (installed 12.x) to v2.
          widget = {
            type = "jellyfin";
            url = local jellyfinPort;
            key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
            version = 2;
          };
        };
      }
    ]
    ++ lib.optionals hl.calibreWeb.enable [
      {
        "Calibre-Web" = {
          icon = "calibre-web.png";
          # Path route strips the prefix but forwards X-Script-Name, which
          # Calibre-Web's ReverseProxyPrefixFix consumes to generate URLs
          # under /books (same class as Navidrome's BaseURL).
          href = "https://${hl.caddyProxy.tailnetDomain}/books";
          description = "Ebook Library";
          siteMonitor = local hl.calibreWeb.port;
        };
      }
    ];

  monitoringServices = lib.optionals hl.monitoring.enable [
    {
      "Grafana" = {
        icon = "grafana.png";
        href = "https://${hl.caddyProxy.tailnetDomain}/grafana";
        description = "Dashboards";
        # Root 301s to the https origin, which the plain-HTTP probe cannot
        # follow, so it reads as a synthesized 500; /api/health answers
        # 200 without a redirect hop.
        siteMonitor = "${local hl.monitoring.grafanaPort}/api/health";
        widget = {
          type = "grafana";
          version = 2;
          url = local hl.monitoring.grafanaPort;
          username = "admin";
          # Credentials never reach services.yaml: Homepage substitutes the
          # token from the environment file at config read time.
          password = "{{HOMEPAGE_VAR_GRAFANA_ADMIN_PASSWORD}}";
        };
      };
    }
    {
      "Prometheus" = {
        icon = "prometheus.png";
        # Prometheus binds 127.0.0.1 only (see monitoring.nix listenAddress),
        # so the UI is published through its own Tailscale Serve port like
        # Zellij and OpenCode; the probe and widget below stay on loopback
        # and are queried server-side from this host.
        href = "https://${hl.caddyProxy.tailnetDomain}:${toString hl.monitoring.prometheusHttpsPort}/";
        description = "Metrics";
        siteMonitor = "${local hl.monitoring.prometheusPort}/-/healthy";
        widget = {
          type = "prometheus";
          url = local hl.monitoring.prometheusPort;
        };
      };
    }
    # uid "logs" (monitoring.nix provisions the dashboard, which needs the Loki
    # datasource). Journald shipped from the fleet by Alloy. The probe is Loki's
    # readiness endpoint, so a dead store shows a red dot instead of a silently
    # empty dashboard. logging.nix is co-imported with this module, so the card
    # exists wherever the dashboard does.
    {
      "Logs" = {
        icon = "loki.png";
        href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/logs";
        siteMonitor = "${local hl.logging.lokiPort}/ready";
      };
    }
  ];

  networkServices = lib.optionals hl.adguardhome.enable [
    {
      "AdGuard Home" = {
        icon = "adguard-home.png";
        # Trailing slash: the admin UI references its CSS/JS relatively,
        # and at /adguard (no slash) those resolve against the site root
        # where the Immich catch-all answers HTML instead of the bundle.
        href = "https://${hl.caddyProxy.tailnetDomain}/adguard/";
        description = "DNS";
        siteMonitor = local hl.adguardhome.port;
        widget = {
          type = "adguard";
          url = local hl.adguardhome.port;
          username = "admin";
          password = "{{HOMEPAGE_VAR_ADGUARD_PASSWORD}}";
        };
      };
    }
  ];

  # Wall power: one card per configured Shelly plug plus the Power dashboard
  # that attributes the draw. The live plug value comes straight from the plug's
  # local RPC (a Prometheus round trip would add latency to a card whose whole
  # point is the instantaneous number), while the plug's own web UI is the card
  # target. wallPower.plugs is the single source of name and address, so no IP
  # is repeated here; the plug cards disappear while it is empty, the dashboard
  # link stays (its CPU/GPU panels fill from the node exporters).
  powerServices = lib.optionals hl.monitoring.enable (
    lib.mapAttrsToList (name: ip: {
      "${name}" = {
        icon = "mdi-power-plug";
        href = "http://${ip}/";
        description = "Wall power (Shelly plug)";
        # Homepage probes a siteMonitor with HEAD first. Every Shelly RPC path
        # answers HEAD with 405 plus an illegal 18-byte body, which Node's HTTP
        # parser rejects (HPE_CLOSED_CONNECTION), so an RPC target logged a
        # proxy error on each poll; an RPC path is not monitorable. The plug's
        # web UI root answers HEAD with a conformant 200, so it is the target.
        siteMonitor = "http://${ip}/";
        widget = {
          type = "customapi";
          url = "http://${ip}/rpc/Switch.GetStatus?id=0";
          # The plug's own meter: watts now, watt-hours since the meter last
          # reset, and mains voltage (a brown-out shows here before anything
          # else complains).
          refreshInterval = 15000;
          mappings = [
            {
              field = "apower";
              label = "Power";
              format = "float";
              suffix = " W";
            }
            {
              field = "aenergy.total";
              label = "Total";
              format = "float";
              suffix = " Wh";
            }
            {
              field = "voltage";
              label = "Voltage";
              format = "float";
              suffix = " V";
            }
          ];
        };
      };
    })
    hl.monitoring.wallPower.plugs
    ++ [
      {
        "Power" = {
          icon = "shelly.png";
          # uid "power" (monitoring.nix provisions the dashboard). Wall power at
          # the plugs plus the CPU/GPU panels that attribute it.
          href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/power";
        };
      }
    ]
  );

  # One card per Nextcloud app instead of a single dashboard link. The app set
  # mirrors the extraApps declaration in nextcloud.nix (calendar, contacts,
  # tasks) plus the bundled Files app, so new cards belong there first.
  #
  # The Tools tab is a stack of full-width bands: the System group runs
  # columns = 1, so each nested subgroup spans the page (a nested subgroup in a
  # row parent otherwise collapses into a single grid cell and crops its cards),
  # and each band lays its own cards out in a row.
  # Smart home: Home Assistant is the control surface for every integration
  # (Zigbee lights included, Samsung appliances via its SmartThings cloud
  # integration), and the Zigbee2MQTT frontend is where pairing happens. Both
  # are root-served Tailscale Serve UIs like the Terminal band.
  smartHomeServices =
    lib.optionals hl.smartHome.enable [
      {
        "Home Assistant" = {
          icon = "mdi-home-assistant";
          href = "https://${hl.caddyProxy.tailnetDomain}:${toString hl.smartHome.httpsPort}/";
          description = "Home automation";
          siteMonitor = local hl.smartHome.port;
        };
      }
    ]
    ++ lib.optionals (hl.smartHome.enable && hl.smartHome.coordinatorUrl != null) [
      {
        "Zigbee2MQTT" = {
          icon = "mdi-zigbee";
          href = "https://${hl.caddyProxy.tailnetDomain}:${toString hl.smartHome.frontendHttpsPort}/";
          description = "Mesh control";
          siteMonitor = local hl.smartHome.frontendPort;
        };
      }
    ];

  cloudServices = lib.optionals hl.nextcloud.enable [
    {
      "Files" = {
        icon = "nextcloud.png";
        href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/files/";
        description = "File Sync";
        # Instance-level light and widget live on the primary card only;
        # repeating them per app card would show four identical probes.
        # Root 302s to https, which the plain-HTTP probe cannot follow
        # (it reads as a synthesized 500), so probe the loopback
        # endpoint blackbox already uses (monitoring.nix).
        siteMonitor = "${local hl.nextcloud.port}/status.php";
        # Loopback works because nextcloud.nix trusts 127.0.0.1 as a domain;
        # probing it there keeps the widget independent of Caddy. The widget
        # reads OCS serverinfo, which rejects login-password auth while TOTP
        # is enabled on the account, so it authenticates with the device token
        # the calendar sync uses.
        widget = {
          type = "nextcloud";
          url = local hl.nextcloud.port;
          username = "admin";
          password = "{{HOMEPAGE_VAR_NEXTCLOUD_APP_PASSWORD}}";
          fields = ["activeusers" "numfiles" "freespace"];
        };
      };
    }
    {
      "Calendar" = {
        icon = "mdi-calendar";
        href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/calendar/dayGridMonth/now";
        description = "Scheduling";
        # Single published share (Personal); the other calendars are
        # task.org task lists with no events. The token URL is the only
        # anonymous read path (DAV itself stays auth-gated), so the
        # widget needs no credentials.
        widget = {
          type = "calendar";
          integrations = [
            {
              type = "ical";
              name = "Personal";
              url = "{{HOMEPAGE_VAR_NEXTCLOUD_ICS_URL}}";
            }
          ];
        };
      };
    }
    {
      "Tasks" = {
        icon = "mdi-clipboard-text";
        href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/tasks/";
        description = "To-dos";
      };
    }
    {
      "Contacts" = {
        icon = "mdi-account-multiple";
        href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/contacts/";
        description = "Address Book";
      };
    }
  ];
  terminalServices =
    lib.optionals hl.zellijWeb.enable [
      {
        "Zellij Web" = {
          icon = "zellij.png";
          # Tailscale Serve endpoint (TLS, tailnet-only). The server binds
          # loopback only, so the LAN IP is unreachable.
          href = "https://${hl.zellijWeb.tailnetDomain}:${toString hl.zellijWeb.httpsPort}";
          description = "Terminal";
          siteMonitor = local hl.zellijWeb.port;
        };
      }
    ]
    ++ lib.optionals hl.opencodeWeb.enable [
      {
        "OpenCode" = {
          icon = "opencode.png";
          href = "https://${hl.opencodeWeb.tailnetDomain}:${toString hl.opencodeWeb.httpsPort}";
          description = "AI Agent";
          siteMonitor = local hl.opencodeWeb.port;
        };
      }
    ];
  utilityServices =
    lib.optionals hl.vaultwarden.enable [
      {
        "Vaultwarden" = {
          # mdi-* via iconify, same family as the Infra/Access cards; the
          # .png names elsewhere have no local config icons/ dir and fall
          # back to the dashboard-icons CDN, which serves all of them.
          icon = "mdi-key-variant";
          href = "https://${hl.caddyProxy.tailnetDomain}:${toString hl.vaultwarden.httpsPort}";
          description = "Password Manager";
          # /alive is unauthenticated liveness; the probe hits the Rocket
          # loopback port, not the Serve front.
          siteMonitor = "${local config.services.vaultwarden.config.ROCKET_PORT}/alive";
        };
      }
    ]
    ++ lib.optionals hl.ntfy.enable [
      {
        "ntfy.sh" = {
          icon = "ntfy.png";
          href = "http://192.168.178.2:${toString ntfyPort}";
          description = "Push Notifications";
          siteMonitor = "http://127.0.0.1:${toString ntfyPort}";
          # auth-default-access is read-write, so the topic needs no
          # credentials for the widget to read the latest alert.
          widget = {
            type = "ntfy";
            url = "http://127.0.0.1:${toString ntfyPort}";
            topic = "homelab-alerts";
          };
        };
      }
    ];
  # Config Health and Nix Telemetry describe the configuration, so they sit in
  # the Nix band next to the repository card.
  nixServices =
    codeServices
    ++ lib.optionals hl.monitoring.enable [
      {
        "Config Health" = {
          icon = "nixos.png";
          # uid "config-health" (monitoring.nix provisions the dashboard). Shows
          # NixOS generation size per deploy and the vitals host health score.
          href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/config-health";
        };
      }
      {
        "Nix Telemetry" = {
          icon = "nixos.png";
          # uid "nix-otel" (monitoring.nix provisions the dashboard). Evaluation,
          # build and substitution timings from Determinate Nix OTel traces.
          href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/nix-otel";
        };
      }
    ];
  systemServices =
    lib.optionals (cloudServices != []) [{"Cloud" = cloudServices;}]
    ++ lib.optionals (terminalServices != []) [{"Terminal" = terminalServices;}]
    ++ lib.optionals (utilityServices != []) [{"Utilities" = utilityServices;}]
    ++ lib.optionals (mediaServices != []) [{"Media" = mediaServices;}]
    ++ lib.optionals (smartHomeServices != []) [{"Smart home" = smartHomeServices;}]
    ++ lib.optionals (nixServices != []) [{"Nix" = nixServices;}]
    ++ lib.optionals (healthServices != []) [{"Health" = healthServices;}];

  # Access: every path to the machine and its management engine. The router is
  # the same FRITZ!Box over LAN and AVM cloud; AMT is the out-of-band fallback
  # from two vantages; Tailscale is the tailnet admin console for route and
  # DNS recovery. Convenience links only: the dashboard runs on the m920q
  # itself, so with the host down these vanish and the phone's saved AMT URL
  # (the IPv4 WAN endpoint) is the authoritative path. Power control is
  # deliberately not a card - the HTTP relay was removed on purpose and the
  # phone issues "ssh m920q desktop-power on|off|status" from a termux widget
  # instead.
  accessServices = [
    {
      # Router: the same FRITZ!Box reached two ways - the LAN address, and the
      # AVM cloud fallback for when only an internet link is available.
      "Router" = [
        {
          "Fritz!Box" = {
            icon = "fritzbox.png";
            href = "http://192.168.178.1";
            description = "Router (LAN)";
            siteMonitor = "http://192.168.178.1";
            # No credentials: the widget reads AVM's status interface, which
            # needs "allow access for applications" plus UPnP status
            # transmission in the router's network settings. http stays on
            # purpose - the TLS handshake against this router is slow.
            widget = {
              type = "fritzbox";
              url = "http://192.168.178.1";
            };
          };
        }
        {
          "MyFRITZ!" = {
            icon = "mdi-cloud";
            # Off-LAN fallback for the LAN address above: the Fritz!Box is only
            # a 192.168.178.x address, which needs the subnet route, while
            # MyFRITZ!Net works from any network with just an internet link.
            href = "https://myfritz.net/";
            description = "Router (cloud)";
          };
        }
        {
          "Fritz!Exporter" = {
            icon = "fritzbox.png";
            # uid "hn51eUggz" (monitoring.nix provisions the fritz dashboard).
            # The router's own metrics belong with the router, not Monitoring.
            href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/hn51eUggz";
          };
        }
      ];
    }
    {
      # AMT: the ME's management UI, reachable two ways. The WAN path runs
      # through the FRITZ!Box DNAT; on the home LAN only HTTPS answers, since
      # the ME's plain 16992 listener serves the host's LMS relay alone. The
      # UI offers no console: SOL and KVM need a redirection client (the
      # amtterm-m920q function, TLS on 16995), so no card can launch them.
      "AMT" = [
        {
          "IPv4 (WAN)" = {
            icon = "mdi-chip";
            href = "https://116.204.198.109:16993";
            description = "Intel AMT via FRITZ!Box, works from any vantage";
            # No siteMonitor: the only host-side probe target is the ME's plain
            # HTTP on 192.168.178.10:16992, whose response Node's HTTP parser
            # rejects (HPE_INVALID_CONSTANT - the ME does not speak conformant
            # HTTP), so Homepage logged a proxy 500 on every poll. The Fritz
            # rule plus ME TLS end to end is verified from outside
            # (check-host) instead.
          };
        }
        {
          "LAN" = {
            icon = "mdi-chip";
            # HTTPS on the LAN endpoint: the ME answers 16993 on the wire,
            # while its plain 16992 listener serves only the host's LMS relay,
            # so a LAN browser must use TLS. The ME's legacy renegotiation is
            # one browsers still allow.
            href = "https://192.168.178.10:16993";
            description = "Intel AMT direct on the home LAN";
          };
        }
      ];
    }
    {
      "Tailscale" = {
        icon = "tailscale.png";
        href = "https://login.tailscale.com/login?next_url=%2Fadmin%2Fmachines%3Frefreshed%3Dtrue";
        description = "Tailnet admin console";
      };
    }
    {
      # NextDNS is the phone's DNS resolver: strict Android Private DNS with
      # Tailscale DNS deliberately off, so a wedged tunnel costs tailnet
      # reachability instead of the phone's internet. Its rewrite mapping
      # m920q.tailf2f0ca.ts.net to the registry tailnetIp (lib/hosts.nix) is
      # what keeps every Tailscale Serve URL resolvable from Android; a stale
      # rewrite silently breaks mobile access to all served UIs.
      "NextDNS" = {
        icon = "nextdns.png";
        href = "https://my.nextdns.io/b99bc7";
        description = "Phone DNS resolver (tailnet-name rewrites)";
        widget = {
          type = "nextdns";
          profile = "b99bc7";
          key = "{{HOMEPAGE_VAR_NEXTDNS_API_KEY}}";
        };
      };
    }
  ];

  # Personal health data, not infrastructure: the Garmin pipeline feeds sleep,
  # stress, body battery, heart rate and activity metrics into InfluxDB and its
  # Grafana dashboard. Folded into the Tools tab's health cluster.
  healthServices = lib.optionals hl.garmin.enable [
    {
      "Garmin Stats" = {
        icon = "garmin.png";
        # uid "garmin-stats" (monitoring.nix provisions the dashboard).
        href = "https://${hl.caddyProxy.tailnetDomain}/grafana/d/garmin-stats";
        description = "Sleep, stress, heart rate, steps";
      };
    }
  ];

  # The configuration repository itself. Homepage ships no GitHub widget (only
  # Gitea/GitLab), so this drives customapi against the REST API: the latest
  # Actions run on main plus the open pull request and issue counts. The counts
  # come from the search API because repos.open_issues_count folds pull
  # requests into issues. Unauthenticated GitHub is capped at 60 requests/hour
  # per IP, below what a polling widget needs, hence the sops token.
  codeServices = lib.optionals (cfg.enable && githubAvailable) [
    {
      "NixOS Repo" = {
        icon = "si-github";
        href = "https://github.com/FelixSchausberger/nixos";
        description = "Configuration repository";
        widgets = [
          {
            type = "customapi";
            url = "https://api.github.com/repos/FelixSchausberger/nixos/actions/workflows/ci.yml/runs?per_page=1&branch=main";
            refreshInterval = 300000;
            headers = githubHeaders;
            mappings = [
              {
                field = "workflow_runs.0.conclusion";
                label = "CI";
                # A run in progress has a null conclusion; "pending" keeps the
                # card readable instead of showing an empty field.
                remap = [
                  {
                    value = "success";
                    to = "passing";
                  }
                  {
                    value = "failure";
                    to = "failing";
                  }
                  {
                    any = true;
                    to = "pending";
                  }
                ];
              }
            ];
          }
          {
            type = "customapi";
            url = "https://api.github.com/search/issues?q=repo:FelixSchausberger/nixos+is:pr+is:open";
            refreshInterval = 300000;
            headers = githubHeaders;
            mappings = [
              {
                field = "total_count";
                label = "Open PRs";
                format = "number";
              }
            ];
          }
          {
            type = "customapi";
            url = "https://api.github.com/search/issues?q=repo:FelixSchausberger/nixos+is:issue+is:open";
            refreshInterval = 300000;
            headers = githubHeaders;
            mappings = [
              {
                field = "total_count";
                label = "Open issues";
                format = "number";
              }
            ];
          }
        ];
      };
    }
  ];

  allServices =
    lib.optionals (accessServices != []) [{"Access" = accessServices;}]
    ++ lib.optionals (infraServices != []) [{"Infrastructure" = infraServices;}]
    ++ lib.optionals (powerServices != []) [{"Power" = powerServices;}]
    ++ lib.optionals (monitoringServices != []) [{"Monitoring" = monitoringServices;}]
    ++ lib.optionals (networkServices != []) [{"Network" = networkServices;}]
    ++ lib.optionals (systemServices != []) [{"System" = systemServices;}];

  # Group arrangement: one tab per concern, horizontal rows inside a tab. Tab
  # names are the only navigation on the page, so a group without a tab would
  # surface on every one of them - each entry below is assigned.
  #
  # The default tab is the first key of the rendered layout, and the YAML
  # generator sorts keys alphabetically, so the first tab is whichever group
  # name sorts first - not the first entry here. "Access" is named to sort
  # ahead of every other group and carry the Home tab; keep that property when
  # adding or renaming groups, or the dashboard opens on the wrong tab.
  groupLayout = {
    Access = {
      tab = "Home";
      icon = "mdi-lifebuoy";
      # Router: LAN and cloud paths to the same FRITZ!Box.
      Router = {
        icon = "fritzbox.png";
      };
      # AMT: WAN and LAN paths to the management UI.
      AMT = {
        icon = "mdi-chip";
      };
    };
    Infrastructure = {
      tab = "Home";
      icon = "mdi-server";
      style = "row";
      columns = 4;
    };
    Power = {
      tab = "Home";
      icon = "mdi-power-plug";
      style = "row";
      columns = 3;
    };
    Monitoring = {
      tab = "Home";
      icon = "mdi-chart-line";
      style = "row";
      columns = 4;
    };
    Network = {
      tab = "Home";
      icon = "mdi-lan-connect";
      style = "row";
      columns = 3;
    };
    System = {
      tab = "Tools";
      icon = "mdi-cog";
      style = "row";
      # columns = 1 makes each nested band span the page instead of collapsing
      # into a single grid cell; the bands lay their own cards out in a row.
      columns = 1;
      Cloud = {
        style = "row";
        columns = 4;
      };
      Terminal = {
        style = "row";
        columns = 2;
      };
      Utilities = {
        style = "row";
        columns = 2;
      };
      Media = {
        style = "row";
        columns = 3;
      };
      "Smart home" = {
        style = "row";
        columns = 2;
      };
      Nix = {
        style = "row";
        columns = 3;
      };
      Health = {
        style = "row";
        columns = 3;
      };
    };
  };
  # Layout keys are intersected with the groups actually rendered. Services
  # without a layout entry self-filter upstream, but the tab bar is built from
  # the raw layout keys, so a key for a disabled group would leave an empty tab
  # behind and shift the default tab (the first one alphabetically).
  groupNames = map (group: builtins.head (builtins.attrNames group)) allServices;
  layout = lib.filterAttrs (name: _: builtins.elem name groupNames) groupLayout;

  # Widget credentials reach Homepage as environment variables, never as YAML
  # values in the store: services.yaml carries {{HOMEPAGE_VAR_*}} tokens that
  # Homepage substitutes when it reads the file. A placeholder only exists for
  # a declared secret, so every entry is gated on the service that declares it
  # and an unused service contributes nothing instead of a dangling token.
  widgetEnv = lib.concatStringsSep "\n" (
    lib.optional hl.monitoring.enable "HOMEPAGE_VAR_GRAFANA_ADMIN_PASSWORD=${config.sops.placeholder."grafana/admin-password"}"
    ++ lib.optional hl.adguardhome.enable "HOMEPAGE_VAR_ADGUARD_PASSWORD=${config.sops.placeholder."adguard/password"}"
    ++ lib.optional hl.nextcloud.enable "HOMEPAGE_VAR_NEXTCLOUD_APP_PASSWORD=${config.sops.placeholder."nextcloud/calendar-app-password"}"
    ++ lib.optional hl.nextcloud.enable "HOMEPAGE_VAR_NEXTCLOUD_ICS_URL=${config.sops.placeholder."nextcloud/calendar-ics-share-url"}"
    ++ lib.optional hl.immich.enable "HOMEPAGE_VAR_IMMICH_API_KEY=${config.sops.placeholder."immich/api-key"}"
    ++ lib.optional hl.jellyfin.enable "HOMEPAGE_VAR_JELLYFIN_API_KEY=${config.sops.placeholder."jellyfin/api-key"}"
    ++ lib.optional hl.navidrome.enable "HOMEPAGE_VAR_NAVIDROME_TOKEN=${config.sops.placeholder."navidrome/token"}"
    ++ lib.optional (cfg.enable && githubAvailable) "HOMEPAGE_VAR_GITHUB_TOKEN=${config.sops.placeholder."github/token"}"
    ++ lib.optional cfg.enable "HOMEPAGE_VAR_NEXTDNS_API_KEY=${config.sops.placeholder."nextdns/api-key"}"
  );
in {
  options.modules.system.homelab.homepage = {
    enable = lib.mkEnableOption "Homepage dashboard — live service status overview";
    port = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.homepage;
      description = "Homepage dashboard HTTP port";
    };
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8445;
      description = "Tailscale Serve HTTPS port terminating TLS for the Homepage dashboard";
    };
    backgroundWallpaper = lib.mkOption {
      type = lib.types.str;
      default = inputs.self.lib.wallpapers.default;
      defaultText = lib.literalExpression "inputs.self.lib.wallpapers.default";
      description = ''
        Wallpaper shown behind the dashboard, by name in lib/wallpapers.nix.
        Defaults to the window manager's wallpaper; the *_blurred overview
        variant is never used for the dashboard.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.httpsPort
          != hl.zellijWeb.httpsPort
          && cfg.httpsPort != hl.opencodeWeb.httpsPort
          && cfg.httpsPort != hl.monitoring.prometheusHttpsPort;
        message = "modules.system.homelab.homepage.httpsPort must differ from the zellij-web, opencode-web and Prometheus Tailscale Serve ports";
      }
    ];

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

    systemd.services.homepage-dashboard = {
      # The widget credential file is planted by the sops activation script,
      # which completes before any unit starts, so the EnvironmentFile is in
      # place without an explicit ordering.
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = lib.mkForce "homepage-dashboard";
        Group = lib.mkForce "homepage-dashboard";
      };
    };

    # The dashboard must be served from the origin root: its Next.js build
    # emits root-absolute /_next and /api URLs (the package carries no
    # basePath), so a path-stripping Caddy prefix loads a page whose assets
    # and API calls land on the Immich catch-all instead. Like zellij-web
    # and opencode-web, it therefore gets its own Tailscale Serve port, which
    # terminates TLS with the node certificate and reaches any device on the
    # tailnet: https://<tailnetDomain>:<httpsPort>/. The gate mirrors
    # allowedHosts below: caddyProxy.tailnetDomain is the only tailnet name
    # this module knows, so without it there is nothing to serve on.
    systemd.services.tailscale-serve-homepage = mkIf hl.caddyProxy.enable (tailscaleServe {
      name = "tailscale-serve-homepage";
      description = "Expose Homepage dashboard via Tailscale Serve";
      inherit (cfg) httpsPort;
      upstreamPort = cfg.port;
      after = ["homepage-dashboard.service"];
      wants = ["homepage-dashboard.service"];
    });

    # The NextDNS account API key backs the dashboard's NextDNS widget, which
    # reads analytics only. The key itself grants account-level API access
    # (profiles are mutable through the API), so it lives in sops and is
    # exposed to Homepage solely as a rendered environment variable; the
    # dashboard is its only consumer, hence the declaration here.
    sops.secrets."nextdns/api-key" = {};

    sops.templates."homepage/env" = {
      content = widgetEnv;
      path = "/run/secrets/homepage/env";
      owner = "homepage-dashboard";
      mode = "0400";
      # Homepage reads HOMEPAGE_VAR_* once per process (memory-cached) and
      # the nixpkgs unit carries no restart trigger, so without this a new or
      # rotated variable reaches the dashboard only after an unrelated
      # restart; sops-nix restarts the unit when the rendered env changes.
      restartUnits = ["homepage-dashboard.service"];
    };

    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.port;
      environmentFiles = [config.sops.templates."homepage/env".path];
      # Tailnet clients arrive through the Tailscale Serve port, which
      # forwards the original Host header with or without the listener port
      # depending on version; without an exact match every tailnet request
      # fails with HTTP 400 "Host validation failed" while localhost still
      # works. Local entries preserve direct loopback checks.
      allowedHosts = lib.concatStringsSep "," (
        lib.optionals hl.caddyProxy.enable [
          hl.caddyProxy.tailnetDomain
          "${hl.caddyProxy.tailnetDomain}:${toString cfg.httpsPort}"
        ]
        ++ [
          "localhost:${toString cfg.port}"
          "127.0.0.1:${toString cfg.port}"
        ]
      );
      services = allServices;
      # No `bookmarks` attribute: the module default is an empty list, and the
      # previous Quick Links group duplicated the Grafana and Nextcloud
      # service cards outright.
      # Header contents: clock, weather and search, all right-aligned. Host
      # gauges moved into the Infrastructure cards (PrometheusMetric), so
      # nothing here reads /proc and the service keeps the upstream
      # ProtectiveProcSubset=pid hardening.
      widgets = [
        {
          datetime = {
            text_size = "xl";
            # English UI, German regional format, 24h clock.
            locale = "de";
            format = {
              dateStyle = "short";
              timeStyle = "short";
              hourCycle = "h23";
            };
          };
        }
        {
          openmeteo = {
            label = "Vienna";
            latitude = 48.2082;
            longitude = 16.3738;
            timezone = "Europe/Vienna";
            units = "metric";
            cache = 10;
          };
        }
        {
          search = {
            provider = ["duckduckgo" "google"];
            target = "_blank";
            showSearchSuggestions = true;
          };
        }
      ];
      settings = {
        title = "Homelab";
        description = "m920q homelab dashboard";
        theme = "dark";
        color = "slate";
        # Boxed wraps the widget strip in one translucent panel that picks up
        # the card blur below, so the widgets read as glass like the service
        # cards rather than floating on the background.
        headerStyle = "boxed";
        inherit layout;
        # Response times render as a plain green/red dot so status reads at a
        # glance next to the widget blocks.
        statusStyle = "dot";
        # Cards get equal height per row and the page spans the window.
        # maxGroupColumns stays unset: it only applies to style: columns
        # groups, and every group on this page is style: row.
        useEqualHeights = true;
        fullWidth = true;
        # Glass cards over the wallpaper background below - cardBlur alone
        # would be invisible against a flat colour.
        cardBlur = "md";
        # A powered-off host leaves its PrometheusMetric blocks empty; hide the
        # fetch-error text so that reads as "no data", not a broken widget.
        hideErrors = true;
        # Tailnet-only dashboard: keep crawlers out of it.
        disableIndexing = true;
        # The version/update footer is noise on a private dashboard.
        hideVersion = true;
        # Wallpaper served by the caddy proxy (the module's config directory is
        # read-only, so the file ships from modules/home/wallpapers instead).
        # backgroundFile is the crisp variant of backgroundWallpaper; opacity
        # blends the image towards the theme colour so the light card text
        # stays legible.
        background = {
          image = "https://${hl.caddyProxy.tailnetDomain}/bg/${backgroundFile}";
          opacity = 60;
        };
        target = "_blank";
        quicklaunch = {
          searchDescriptions = true;
          provider = "duckduckgo";
        };
      };
      # Fallback for the wallpaper: if the caddy route is unreachable the
      # theme-colour overlay above this sits on the gradient instead of the
      # image. The global stylesheet paints a flat background-color on html
      # and body, hence !important.
      customCSS = ''
        html, body {
          background: linear-gradient(160deg, #0f172a 0%, #1e293b 45%, #0f172a 100%) !important;
          background-attachment: fixed;
        }
      '';
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
