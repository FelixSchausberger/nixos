{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.caddyProxy;
  hl = config.modules.system.homelab;

  # When publicDomain is set every service moves to its own hostname under
  # that apex and the path-routed MagicDNS layout is not rendered at all.
  # The switch is all-or-nothing because service base URLs (Grafana's
  # serve_from_sub_path, Navidrome's BaseURL, Nextcloud's overwritewebroot)
  # are mutually exclusive with prefix routing.
  public = cfg.publicDomain != null;

  # Path-routed Caddy handle_path block that strips the prefix and
  # reverse-proxies to a local service. Only used in the MagicDNS layout,
  # where all routes live under the single Tailscale-issued hostname.
  mkRoute = path: upstreamPort: ''
    handle_path /${path}* {
      reverse_proxy http://127.0.0.1:${toString upstreamPort}
    }
  '';

  # For services that mount their own sub-path (Grafana with
  # serve_from_sub_path, Navidrome with BaseURL), the prefix must reach
  # the upstream intact because the service generates redirects and asset
  # URLs under it; handle_path would strip it and break those.
  mkKeepRoute = path: upstreamPort: ''
    handle /${path}* {
      reverse_proxy http://127.0.0.1:${toString upstreamPort}
    }
  '';

  # For services that consume the X-Script-Name header instead of serving
  # under their own base path (Calibre-Web's ReverseProxyPrefixFix): the
  # prefix is stripped on the way in and re-declared via the header, so
  # links and redirects the app generates stay under /<path> client-side.
  mkScriptNameRoute = path: upstreamPort: ''
    handle_path /${path}* {
      reverse_proxy http://127.0.0.1:${toString upstreamPort} {
        header_up X-Script-Name /${path}
      }
    }
  '';

  # CalDAV/CardDAV clients and Nextcloud's service discovery probe the
  # .well-known endpoints at the site root; with Nextcloud served under a
  # sub-path these must redirect into it. webfinger/nodeinfo are only served
  # by Nextcloud's front controller, which also answers them with the
  # X-NEXTCLOUD-WELL-KNOWN header the setup check looks for.
  mkWellKnownRedirects = path: ''
    redir /.well-known/carddav ${path}/remote.php/dav permanent
    redir /.well-known/caldav ${path}/remote.php/dav permanent
    redir /.well-known/host-meta ${path}/public.php?service=host-meta permanent
    redir /.well-known/host-meta.json ${path}/public.php?service=host-meta-json permanent
    redir /.well-known/webfinger ${path}/index.php/.well-known/webfinger permanent
    redir /.well-known/nodeinfo ${path}/index.php/.well-known/nodeinfo permanent
  '';

  # One subdomain virtual host terminating TLS with the wildcard certificate
  # from security.acme. Caddy listens on the hostname and redirects plain
  # HTTP itself, which .dev requires because the whole TLD is HSTS-preloaded.
  mkHost = upstreamPort: {
    useACMEHost = cfg.publicDomain;
    extraConfig = ''
      header Strict-Transport-Security "max-age=15552000; includeSubDomains"
      reverse_proxy http://127.0.0.1:${toString upstreamPort}
    '';
  };

  # Homepage's background image, shipped for the browser to fetch. Homepage's
  # config directory is a read-only store path and its public directory
  # belongs to the package, so the dashboard cannot serve the file itself. The
  # file follows homepage.backgroundWallpaper but takes the crisp variant:
  # the *_blurred files carry the soft frame the niri overview needs, which the
  # dashboard background must not show.
  homepageWallpaperFile =
    inputs.self.lib.wallpapers.available.${hl.homepage.backgroundWallpaper};
  homepageWallpaper = pkgs.runCommand "homepage-wallpaper" {} ''
    install -Dm444 ${../../home/wallpapers}/${homepageWallpaperFile} $out/${homepageWallpaperFile}
  '';

  # Static route for that image. The longer /bg match wins over the
  # catch-all below, so the route order in extraConfig does not matter.
  wallpaperRoute = ''
    handle_path /bg* {
      root * ${homepageWallpaper}
      file_server
    }
  '';

  # Dynamic route for the selector-published image. The exact path handler is
  # declared before the static /bg* handler; Caddy's handle blocks are
  # mutually exclusive, so current.jpg is served from the live directory
  # instead of the store copy. no-store makes the browser refetch on reload
  # rather than reuse the previous wallpaper.
  dynamicWallpaperRoute = ''
    handle /bg/current.jpg {
      root * ${hl.homepage.backgroundWallpaperDir}
      rewrite * /current.jpg
      header Cache-Control "no-store"
      file_server
    }
  '';

  # Homepage emits root-absolute /_next and /api URLs, so it needs the origin
  # root: at home.<publicDomain> its own hostname provides exactly that, and
  # the wallpaper handlers share the same origin with the dashboard.
  homepageConfig =
    ''
      header Strict-Transport-Security "max-age=15552000; includeSubDomains"
    ''
    + lib.optionalString (hl.homepage.backgroundWallpaperDir != null) dynamicWallpaperRoute
    + wallpaperRoute
    + ''
      handle {
        reverse_proxy http://127.0.0.1:${toString hl.homepage.port}
      }
    '';
in {
  options.modules.system.homelab.caddyProxy = {
    enable = lib.mkEnableOption "Caddy reverse proxy for Tailscale-accessible homelab services";

    tailnetDomain = lib.mkOption {
      type = lib.types.str;
      example = "m920q.tailf2f0ca.ts.net";
      description = "MagicDNS hostname for this node (host.tailnet.ts.net). Tailscale issues the TLS certificate for it, and the path-routed service layout lives here when publicDomain is null.";
    };

    publicDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "schausberger.dev";
      description = ''
        Apex domain under which each service is served as its own hostname
        (photos.<domain>, cloud.<domain>, ...). The wildcard certificate is
        issued with an ACME DNS-01 challenge at Cloudflare, so the zone's
        nameservers must be Cloudflare's and the sops secret
        acme/cloudflare-dns-token must hold a token with DNS edit permission
        for the zone. When null, services stay on path routes under
        tailnetDomain and no public certificate is requested.
      '';
    };

    acmeEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Contact address for the ACME account. Required when publicDomain is set so expiry warnings reach a human.";
    };

    acmeEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Environment file for lego holding CLOUDFLARE_DNS_API_TOKEN, the
        credential for the DNS-01 challenge. The host owns the file (sops
        template), so the module works on hosts without the sops module too.
        Required when publicDomain is set.
      '';
    };

    # Per-service toggles default to true when the corresponding service is
    # enabled, so enabling caddyProxy on a host automatically exposes all
    # active services without manual opt-in per service.
    immich = lib.mkOption {
      type = lib.types.bool;
      default = hl.immich.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.immich.enable";
      description = "Expose Immich at the root of the tailnet hostname or at photos.<publicDomain>";
    };

    navidrome = lib.mkOption {
      type = lib.types.bool;
      default = hl.navidrome.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.navidrome.enable";
      description = "Expose Navidrome at <tailnetDomain>/navidrome or at music.<publicDomain>";
    };

    grafana = lib.mkOption {
      type = lib.types.bool;
      default = hl.monitoring.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.monitoring.enable";
      description = "Expose Grafana at <tailnetDomain>/grafana or at grafana.<publicDomain>";
    };

    adguard = lib.mkOption {
      type = lib.types.bool;
      default = hl.adguardhome.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.adguardhome.enable";
      description = "Expose AdGuard Home at <tailnetDomain>/adguard or at adguard.<publicDomain>";
    };

    nextcloud = lib.mkOption {
      type = lib.types.bool;
      default = hl.nextcloud.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.nextcloud.enable";
      description = "Expose Nextcloud at <tailnetDomain>/nextcloud or at cloud.<publicDomain>";
    };

    calibreWeb = lib.mkOption {
      type = lib.types.bool;
      default = hl.calibreWeb.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.calibreWeb.enable";
      description = "Expose Calibre-Web at <tailnetDomain>/books or at books.<publicDomain>";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = cfg.tailnetDomain != "";
          message = "modules.system.homelab.caddyProxy.tailnetDomain must be set (e.g. 'm920q.tailf2f0ca.ts.net')";
        }
        {
          assertion = !cfg.immich || hl.immich.enable;
          message = "caddyProxy.immich requires modules.system.homelab.immich.enable = true";
        }
        {
          assertion = !cfg.navidrome || hl.navidrome.enable;
          message = "caddyProxy.navidrome requires modules.system.homelab.navidrome.enable = true";
        }
        {
          assertion = !cfg.grafana || hl.monitoring.enable;
          message = "caddyProxy.grafana requires modules.system.homelab.monitoring.enable = true";
        }
        {
          assertion = !cfg.adguard || hl.adguardhome.enable;
          message = "caddyProxy.adguard requires modules.system.homelab.adguardhome.enable = true";
        }
        {
          assertion = !cfg.nextcloud || hl.nextcloud.enable;
          message = "caddyProxy.nextcloud requires modules.system.homelab.nextcloud.enable = true";
        }
        {
          assertion = !cfg.calibreWeb || hl.calibreWeb.enable;
          message = "caddyProxy.calibreWeb requires modules.system.homelab.calibreWeb.enable = true";
        }
      ]
      ++ lib.optionals public [
        {
          assertion = cfg.acmeEmail != null;
          message = "caddyProxy.acmeEmail must be set when publicDomain is used, so certificate expiry warnings reach a human";
        }
        {
          assertion = cfg.acmeEnvironmentFile != null;
          message = "caddyProxy.acmeEnvironmentFile must point at a root-readable file holding CLOUDFLARE_DNS_API_TOKEN when publicDomain is used";
        }
      ];

    # Allow Caddy to fetch TLS certificates from the local Tailscale daemon.
    # Without this, tailscaled rejects cert requests from the caddy user.
    services.tailscale.permitCertUid = "caddy";

    # The Cloudflare API token for the DNS-01 challenge is supplied by the
    # host as an environment file; the module never reads sops directly so it
    # can be evaluated on hosts without the sops module (VM tests included).
    security.acme.acceptTerms = lib.mkIf public true;
    security.acme.certs.${cfg.publicDomain} = lib.mkIf public {
      domain = cfg.publicDomain;
      extraDomainNames = ["*.${cfg.publicDomain}"];
      dnsProvider = "cloudflare";
      environmentFile = cfg.acmeEnvironmentFile;
      group = "caddy";
      email = cfg.acmeEmail;
    };

    services.caddy = {
      enable = true;
      # All certificates come from security.acme (public hostnames) or the
      # Tailscale daemon (MagicDNS hostname); disable Caddy's own ACME
      # resolver to avoid unnecessary outbound traffic.
      acmeCA = null;

      virtualHosts =
        if public
        then
          lib.optionalAttrs hl.homepage.enable {
            "home.${cfg.publicDomain}" = {
              useACMEHost = cfg.publicDomain;
              extraConfig = homepageConfig;
            };
          }
          // lib.optionalAttrs cfg.immich {
            "photos.${cfg.publicDomain}" = mkHost hl.immich.port;
          }
          // lib.optionalAttrs cfg.navidrome {
            "music.${cfg.publicDomain}" = mkHost hl.navidrome.port;
          }
          // lib.optionalAttrs cfg.grafana {
            "grafana.${cfg.publicDomain}" = mkHost hl.monitoring.grafanaPort;
          }
          // lib.optionalAttrs cfg.adguard {
            "adguard.${cfg.publicDomain}" = mkHost hl.adguardhome.port;
          }
          // lib.optionalAttrs cfg.nextcloud {
            "cloud.${cfg.publicDomain}" = mkHost hl.nextcloud.port;
          }
          // lib.optionalAttrs cfg.calibreWeb {
            "books.${cfg.publicDomain}" = mkHost hl.calibreWeb.port;
          }
        else {
          ${cfg.tailnetDomain} = {
            extraConfig =
              ''
                tls {
                  get_certificate tailscale
                }
                # Caddy is the TLS endpoint; the upstream only sees plain HTTP,
                # so HSTS has to be set here. No preload: that is a
                # browser-distributed commitment this host cannot recall.
                header Strict-Transport-Security "max-age=15552000; includeSubDomains"
              ''
              + lib.optionalString cfg.navidrome (mkKeepRoute "navidrome" hl.navidrome.port)
              + lib.optionalString cfg.grafana (mkKeepRoute "grafana" hl.monitoring.grafanaPort)
              + lib.optionalString cfg.adguard (mkRoute "adguard" hl.adguardhome.port)
              + lib.optionalString cfg.nextcloud (mkRoute "nextcloud" hl.nextcloud.port)
              + lib.optionalString cfg.calibreWeb (mkScriptNameRoute "books" hl.calibreWeb.port)
              + lib.optionalString (hl.homepage.enable && hl.homepage.backgroundWallpaperDir != null) dynamicWallpaperRoute
              + lib.optionalString hl.homepage.enable wallpaperRoute
              # .well-known redirects win over the Immich catch-all below: Caddy
              # routes to the handle whose path matcher is the longest match.
              + lib.optionalString cfg.nextcloud (mkWellKnownRedirects "/nextcloud")
              # Immich is served at root via a catch-all handle (lower priority than handle_path
              # blocks above). Tailscale only issues certs for the exact MagicDNS hostname, not
              # subdomains, so a dedicated virtualHost is not possible without external DNS.
              + lib.optionalString cfg.immich ''
                handle {
                  reverse_proxy http://127.0.0.1:${toString hl.immich.port}
                }
              '';
          };
        };
    };

    # Caddy state must survive reboots on an impermanence system.
    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/caddy";
        user = "caddy";
        group = "caddy";
        mode = "0700";
      }
    ];
  };
}
