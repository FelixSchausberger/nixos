{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.homelab.caddyProxy;
  hl = config.modules.system.homelab;

  # Build a path-routed Caddy handle_path block that strips the prefix and
  # reverse-proxies to a local service. All routes live under the single
  # MagicDNS hostname; Tailscale issues one cert for that name.
  mkRoute = path: upstreamPort: ''
    handle_path /${path}* {
      reverse_proxy http://127.0.0.1:${toString upstreamPort}
    }
  '';

  # CalDAV/CardDAV clients and Nextcloud's service discovery probe the
  # .well-known endpoints at the site root; with Nextcloud served under a
  # sub-path these must redirect into it.
  mkWellKnownRedirects = path: ''
    redir /.well-known/carddav ${path}/remote.php/dav permanent
    redir /.well-known/caldav ${path}/remote.php/dav permanent
    redir /.well-known/host-meta ${path}/public.php?service=host-meta permanent
    redir /.well-known/host-meta.json ${path}/public.php?service=host-meta-json permanent
  '';
in {
  options.modules.system.homelab.caddyProxy = {
    enable = lib.mkEnableOption "Caddy reverse proxy for Tailscale-accessible homelab services";

    tailnetDomain = lib.mkOption {
      type = lib.types.str;
      example = "m920q.tailf2f0ca.ts.net";
      description = "MagicDNS hostname for this node (host.tailnet.ts.net). Caddy listens on this name and Tailscale issues the TLS certificate for it.";
    };

    # Per-service toggles default to true when the corresponding service is
    # enabled, so enabling caddyProxy on a host automatically exposes all
    # active services without manual opt-in per service.
    immich = lib.mkOption {
      type = lib.types.bool;
      default = hl.immich.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.immich.enable";
      description = "Expose Immich via Tailscale at <tailnetDomain> root (catch-all handle, lower priority than path-routed services)";
    };

    navidrome = lib.mkOption {
      type = lib.types.bool;
      default = hl.navidrome.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.navidrome.enable";
      description = "Expose Navidrome via Tailscale at <tailnetDomain>/navidrome";
    };

    grafana = lib.mkOption {
      type = lib.types.bool;
      default = hl.monitoring.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.monitoring.enable";
      description = "Expose Grafana via Tailscale at <tailnetDomain>/grafana";
    };

    adguard = lib.mkOption {
      type = lib.types.bool;
      default = hl.adguardhome.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.adguardhome.enable";
      description = "Expose AdGuard Home via Tailscale at <tailnetDomain>/adguard";
    };

    nextcloud = lib.mkOption {
      type = lib.types.bool;
      default = hl.nextcloud.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.nextcloud.enable";
      description = "Expose Nextcloud via Tailscale at <tailnetDomain>/nextcloud";
    };

    homepage = lib.mkOption {
      type = lib.types.bool;
      default = hl.homepage.enable;
      defaultText = lib.literalExpression "config.modules.system.homelab.homepage.enable";
      description = "Expose Homepage dashboard via Tailscale at <tailnetDomain>/homepage";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
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
        assertion = !cfg.homepage || hl.homepage.enable;
        message = "caddyProxy.homepage requires modules.system.homelab.homepage.enable = true";
      }
    ];

    # Allow Caddy to fetch TLS certificates from the local Tailscale daemon.
    # Without this, tailscaled rejects cert requests from the caddy user.
    services.tailscale.permitCertUid = "caddy";

    services.caddy = {
      enable = true;
      # All certs come from Tailscale via get_certificate tailscale; disable
      # the default ACME resolver to avoid unnecessary outbound traffic.
      acmeCA = null;

      virtualHosts.${cfg.tailnetDomain} = {
        extraConfig =
          ''
            tls {
              get_certificate tailscale
            }
          ''
          + lib.optionalString cfg.navidrome (mkRoute "navidrome" hl.navidrome.port)
          + lib.optionalString cfg.grafana (mkRoute "grafana" hl.monitoring.grafanaPort)
          + lib.optionalString cfg.adguard (mkRoute "adguard" hl.adguardhome.port)
          + lib.optionalString cfg.nextcloud (mkRoute "nextcloud" hl.nextcloud.port)
          + lib.optionalString cfg.homepage (mkRoute "homepage" hl.homepage.port)
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
