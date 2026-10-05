{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.homepage;
  hl = config.modules.system.homelab;
  inherit (lib) mkIf;

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

  # Build services YAML from enabled homelab services
  # Remote wake for the gaming PC lives on the router, not here:
  # Fritz!Box Heimnetz → computer → "Computer starten" (or MyFRITZ!App
  # when off-LAN). The Moonlight / Steam Link apps handle wake + presence
  # on the LAN themselves. The Fritz!Box card under Rescue links there.
  infraServices = [
    {
      "M920q" = {
        icon = "mdi-server";
        href = "http://192.168.178.2:${toString hl.monitoring.grafanaPort}";
        description = "Homelab Server";
        # node_exporter answers on loopback only and stands in for the host
        # itself: if it stops answering, the monitoring stack is blind, which
        # is the condition this card exists to reveal.
        siteMonitor = "${local hl.monitoring.nodeExporterPort}/metrics";
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
        };
      }
    ];

  monitoringServices = lib.optionals hl.monitoring.enable [
    {
      "Grafana" = {
        icon = "grafana.png";
        href = "https://${hl.caddyProxy.tailnetDomain}/grafana";
        description = "Dashboards";
        siteMonitor = local hl.monitoring.grafanaPort;
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

  # One card per Nextcloud app instead of a single dashboard link. The app
  # set mirrors the extraApps declaration in nextcloud.nix (calendar,
  # contacts, tasks) plus the bundled Files app, so new cards belong there
  # first.
  systemServices =
    lib.optionals hl.nextcloud.enable [
      {
        "Files" = {
          icon = "nextcloud.png";
          href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/files/";
          description = "File Sync";
          # Instance-level light and widget live on the primary card only;
          # repeating them per app card would show four identical probes.
          siteMonitor = local hl.nextcloud.port;
          # Loopback works because nextcloud.nix trusts 127.0.0.1 as a domain;
          # probing it there keeps the widget independent of Caddy.
          widget = {
            type = "nextcloud";
            url = local hl.nextcloud.port;
            username = "admin";
            password = "{{HOMEPAGE_VAR_NEXTCLOUD_ADMIN_PASSWORD}}";
            fields = ["activeusers" "numfiles" "freespace"];
          };
        };
      }
      {
        "Calendar" = {
          icon = "mdi-calendar";
          href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/calendar/dayGridMonth/now";
          description = "Scheduling";
        };
      }
      {
        "Contacts" = {
          icon = "mdi-account-multiple";
          href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/contacts/";
          description = "Address Book";
        };
      }
      {
        "Tasks" = {
          icon = "mdi-clipboard-text";
          href = "https://${hl.caddyProxy.tailnetDomain}/nextcloud/apps/tasks/";
          description = "To-dos";
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
    ]
    ++ lib.optionals hl.zellijWeb.enable [
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
    ]
    ++ lib.optionals hl.vaultwarden.enable [
      {
        "Vaultwarden" = {
          # mdi-* via iconify, same family as the Infra/Rescue cards; the
          # .png names elsewhere resolve against a config icons/ dir this
          # host does not have.
          icon = "mdi-key-variant";
          href = "https://${hl.caddyProxy.tailnetDomain}:${toString hl.vaultwarden.httpsPort}";
          description = "Password Manager";
          # /alive is unauthenticated liveness; the probe hits the Rocket
          # loopback port, not the Serve front.
          siteMonitor = "${local config.services.vaultwarden.config.ROCKET_PORT}/alive";
        };
      }
    ];

  # Emergency access: Intel AMT from each vantage (LAN, WAN via FRITZ!Box
  # DNAT, IPv6), the router on LAN with MyFRITZ!Net as its off-LAN
  # fallback, and the tailnet admin console for route and DNS recovery.
  # Convenience links only: the dashboard runs on the m920q itself, so
  # with the host down these vanish and the phone's pinned browser
  # bookmarks (AMT over IPv4 and IPv6) are the authoritative path. Power
  # control is deliberately not a card - the HTTP relay was removed on
  # purpose and the phone issues
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
    {
      "AMT (LAN)" = {
        icon = "mdi-chip";
        # Plain HTTP on the LAN endpoint: no ME legacy-TLS negotiation for
        # the browser to reject, and the phone reaches it through the
        # advertised 192.168.178.0/24 subnet route.
        href = "http://192.168.178.10:16992/index.htm";
        description = "Intel AMT direct on the home LAN";
        siteMonitor = "http://192.168.178.10:16992/";
      };
    }
    {
      "Fritz!Box" = {
        icon = "fritzbox.png";
        href = "http://192.168.178.1";
        description = "Router";
        siteMonitor = "http://192.168.178.1";
      };
    }
    {
      "MyFRITZ!" = {
        icon = "mdi-cloud";
        # Off-LAN fallback for the LAN router card above: the Fritz!Box is
        # only a 192.168.178.x address, which needs the subnet route, while
        # MyFRITZ!Net works from any network with just an internet link.
        href = "https://myfritz.net/";
        description = "Router via AVM cloud";
      };
    }
    {
      "Tailscale" = {
        icon = "tailscale.png";
        href = "https://login.tailscale.com/login?next_url=%2Fadmin%2Fmachines%3Frefreshed%3Dtrue";
        description = "Tailnet admin console";
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

  # Group arrangement: one tab per concern, horizontal rows inside a tab.
  # Tab names are the only navigation on the page, so a group without a tab
  # would surface on every one of them - each entry below is assigned.
  groupLayout = {
    Rescue = {
      tab = "Home";
      icon = "mdi-lifebuoy";
    };
    Infrastructure = {
      tab = "Home";
      icon = "mdi-server";
      style = "row";
      columns = 4;
    };
    Media = {
      tab = "Media";
      icon = "mdi-play";
      style = "row";
      columns = 3;
    };
    Monitoring = {
      tab = "Home";
      icon = "mdi-chart-line";
      style = "row";
      columns = 3;
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
      columns = 3;
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
    ++ lib.optional hl.nextcloud.enable "HOMEPAGE_VAR_NEXTCLOUD_ADMIN_PASSWORD=${config.sops.placeholder."nextcloud/admin-password"}"
  );
in {
  options.modules.system.homelab.homepage = {
    enable = lib.mkEnableOption "Homepage dashboard — live service status overview";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3002;
      description = "Homepage dashboard HTTP port";
    };
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8445;
      description = "Tailscale Serve HTTPS port terminating TLS for the Homepage dashboard";
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
      # The widget credential file is planted by sops-nix at activation; the
      # unit fails to start if EnvironmentFile points at a path that does not
      # exist yet, so it waits for the installer (same pattern as garmin.nix).
      after = ["sops-nix.service"];
      wants = ["sops-nix.service"];
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
    systemd.services.tailscale-serve-homepage = mkIf hl.caddyProxy.enable {
      description = "Expose Homepage dashboard via Tailscale Serve";
      after = [
        "tailscale.service"
        "homepage-dashboard.service"
      ];
      wants = [
        "tailscale.service"
        "homepage-dashboard.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 30;
        Restart = "on-failure";
        RestartSec = 30;
        ExecStart = "${pkgs.writeShellScript "tailscale-serve-homepage-setup" ''
          ${pkgs.tailscale}/bin/tailscale serve --bg \
            --https ${toString cfg.httpsPort} \
            http://127.0.0.1:${toString cfg.port}
        ''}";
      };
      # Fail loudly and retry when tailscaled is not yet connected; never
      # swallow the error into a green "active (exited)" state. Re-serve
      # whenever tailscaled comes back up.
      upholds = ["tailscale.service"];
      unitConfig.StartLimitBurst = 5;
      unitConfig.StartLimitIntervalSec = 300;
    };

    sops.templates."homepage/env" = {
      content = widgetEnv;
      path = "/run/secrets/homepage/env";
      owner = "homepage-dashboard";
      mode = "0400";
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
      # Header contents, left to right: greeting and host gauges on the left,
      # clock, weather and search right-aligned. Setting resources.cpu is what
      # makes the upstream module relax ProcSubset so /proc stays readable.
      widgets = [
        {
          greeting = {
            text_size = "2xl";
            text = "Welcome";
          };
        }
        {
          resources = {
            label = "m920q";
            cpu = true;
            memory = true;
            disk = [
              "/"
              "/per"
              "/per/mnt/data"
            ];
            uptime = true;
            network = "eno1";
          };
        }
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
        headerStyle = "clean";
        inherit layout;
        # Response times render as a plain green/red dot so status reads at a
        # glance next to the widget blocks.
        statusStyle = "dot";
        # Cards get equal height per row and the page spans the window.
        # maxGroupColumns stays unset: it only applies to style: columns
        # groups, and every group on this page is style: row.
        useEqualHeights = true;
        fullWidth = true;
        # Glass cards over the gradient in customCSS below - cardBlur alone
        # would be invisible against a flat colour.
        cardBlur = "md";
        target = "_blank";
        quicklaunch = {
          searchDescriptions = true;
          provider = "duckduckgo";
        };
      };
      # The config directory is read-only, so a background image cannot ship
      # with the module; a gradient stands in for one and is what the card
      # blur has to work against. The global stylesheet paints a flat
      # background-color on html and body, hence !important.
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
