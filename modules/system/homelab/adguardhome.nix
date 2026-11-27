{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.adguardhome;
  hl = config.modules.system.homelab;
in {
  options.modules.system.homelab.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home DNS ad-blocker";
    port = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.adguard;
      description = "Admin UI HTTP port";
    };
    exporterPort = lib.mkOption {
      type = lib.types.port;
      default = 9618;
      description = "Prometheus exporter HTTP port (localhost only)";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the AdGuard Home web UI port in the firewall. DNS (53 TCP/UDP) is always opened separately; the web UI is reached over the tailnet through Caddy on this host.";
    };
    rewrites = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {"*.example.com" = "100.64.0.1";};
      description = ''
        DNS rewrites answered for every client of this resolver. A wildcard
        covers the subdomains but not the apex, which is what points the
        homelab's public hostnames at the tailnet address of the Caddy node:
        the records stay private to this resolver and never enter public DNS.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.port != 53;
        message = "AdGuard Home admin UI port must not be 53 (reserved for DNS service)";
      }
      {
        assertion =
          !hl.monitoring.enable
          || cfg.port
          != hl.monitoring.grafanaPort;
        message = "AdGuard Home admin UI port must differ from Grafana port when monitoring is enabled";
      }
    ];

    # AdGuard is the single LAN resolver for IPv4 and IPv6; systemd-resolved
    # stays local-only (127.0.0.53) and forwards the m920q's own lookups to
    # AdGuard on 127.0.0.1:53. The LAN IPv6 address is in AdGuard's bind_hosts
    # below, so the router's RA RDNSS (which points IPv6 clients at this host)
    # lands on AdGuard directly instead of a second stub resolver - one
    # resolver, so v4 and v6 clients get identical answers.
    # FallbackDNS covers the m920q itself when AdGuard is unreachable.
    services.resolved.settings.Resolve = {
      DNS = "127.0.0.1:53";
      FallbackDNS = "1.1.1.1 9.9.9.9";
    };

    services.adguardhome = {
      enable = true;
      inherit (cfg) openFirewall;
      settings = {
        # Admin UI port — bound to loopback. The Caddy /adguard route and the
        # exporter both connect through 127.0.0.1; the LAN reaches DNS only.
        http.address = "127.0.0.1:${toString cfg.port}";
        dns = {
          # Quad9 is reached over DoT: its DoH endpoint intermittently closes
          # HTTP connections with "unexpected EOF" (AdGuardHome#8311), while
          # DoT keeps the same filtering and DNSSEC validation without the
          # HTTP transport. Cloudflare stays DoH as the unfiltered second
          # resolver.
          upstream_dns = [
            "https://dns.cloudflare.com/dns-query"
            "tls://dns.quad9.net"
          ];
          # Fail over to fallback_dns quickly instead of waiting 10s on a
          # connection that will never answer.
          upstream_timeout = "3s";
          # Fallback resolvers, only consulted when both primary upstreams
          # fail. NextDNS comes first so a stalled provider turns into a
          # filtered fallback instead of a hard DNS outage (observed
          # 2026-09-15); the plain resolvers stay behind it as the last resort
          # when NextDNS is unreachable too. This is the NextDNS fallback; do
          # not also add NextDNS as a second tailnet global nameserver
          # (Tailscale races resolvers, so AdGuard would answer around a
          # NextDNS denial).
          fallback_dns = [
            "https://dns.nextdns.io/b99bc7"
            "9.9.9.9"
            "1.1.1.1"
          ];
          bootstrap_dns = [
            "9.9.9.9"
            "1.1.1.1"
          ];
          # LAN faces: 192.168.178.2 (IPv4) and the ULA (IPv6, the address the
          # router's RA advertises as RDNSS), so every LAN client reaches
          # AdGuard directly. Publish the tailnet IP as the sole tailnet global
          # nameserver in the admin console so roaming Tailscale clients use
          # AdGuard too; AdGuard's fallback_dns carries NextDNS when its
          # encrypted upstreams fail. 127.0.0.1 is the host's own path through
          # resolved.
          bind_hosts = [
            "127.0.0.1"
            "192.168.178.2"
            "fd50:5bc:d390:0:ea6a:64ff:fe9f:a050"
            "100.105.37.12"
          ];
          port = 53;
          # AdGuard schema v34 reads cache settings as flat cache_* keys under
          # dns; a nested "caching:" block is ignored, which is why defaults
          # (cache_optimistic=false) were in force. Optimistic caching answers
          # from stale entries while upstreams are unreachable instead of
          # failing every lookup.
          cache_enabled = true;
          cache_optimistic = true;
          # Validate DNSSEC where the upstreams publish it: AdGuard answers
          # SERVFAIL for a domain with a broken signature instead of resolving
          # it, which is the point. Cloudflare DoH and Quad9 DoT validate.
          enable_dnssec = true;
        };

        # Blocklists owned by the flake rather than the admin UI. The live
        # configuration carried eleven heavily overlapping lists that no
        # repository change could reproduce; two curated ones cover ads and
        # trackers with far less redundancy, and both are AdGuard-published so
        # they stay current. AdGuard merges declared settings over the web UI
        # on start, so filters must be edited here now, not in the UI.
        filters = [
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
            name = "AdGuard DNS filter";
            id = 1;
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_34.txt";
            name = "HaGeZi's Normal Blocklist";
            id = 34;
          }
        ];
        querylog.enabled = true;
        querylog.interval = "7d";
        querylog.size_memory = 1000;
        filtering =
          {
            response_ttl_secs = 86400;
          }
          // lib.optionalAttrs (cfg.rewrites != {}) {
            rewrites = lib.mapAttrsToList (domain: answer: {inherit domain answer;}) cfg.rewrites;
          };
        user_rules = [
          # Windows NCSI — prevents "No Internet" indicator on Windows clients
          "@@||msftconnecttest.com^"
          "@@||msftncsi.com^"
          "@@||ipv6.msftncsi.com^"

          # macOS/iOS captive portal and connectivity detection
          "@@||captive.apple.com^"
          "@@||www.apple.com^"
          "@@||gateway.icloud.com^"

          # Android/Chrome OS connectivity checks
          "@@||connectivitycheck.gstatic.com^"
          "@@||connectivitycheck.android.com^"
          "@@||clients1.google.com^"
          "@@||clients3.google.com^"

          # Windows Update
          "@@||windowsupdate.microsoft.com^"
          "@@||update.microsoft.com^"
          "@@||download.microsoft.com^"

          # Apple Software Update
          "@@||swscan.apple.com^"
          "@@||swquery.apple.com^"
          "@@||swcdn.apple.com^"

          # Mozilla update and experimentation
          "@@||normandy.cdn.mozilla.net^"
          "@@||aus5.mozilla.org^"

          # Certificate revocation (OCSP/CRL) — blocking causes browser TLS errors
          "@@||ocsp.digicert.com^"
          "@@||ocsp.pki.goog^"
          "@@||crl.microsoft.com^"
          "@@||ssl-crl.microsoft.com^"

          # Windows settings sync — misflagged by aggressive lists but functionally required
          "@@||activity.windows.com^"
          "@@||settings-win.data.microsoft.com^"
        ];
      };
    };

    users.users.adguardhome = {
      isSystemUser = true;
      group = "adguardhome";
    };
    users.groups.adguardhome = {};

    # The upstream NixOS module sets DynamicUser=true, which creates a private-namespace
    # bind mount at /var/lib/AdGuardHome. This conflicts with impermanence's bind mount
    # already in place at that path ("Device or resource busy"), and the transient uid
    # it creates cannot write to directories it doesn't own.
    # A static user sidesteps both problems, matching the pattern used by rustdesk.nix.
    systemd.services.adguardhome = {
      # Startup is ordered after the tailnet is actually usable, not merely
      # after tailscaled.service starts: bind_hosts include the node's tailnet
      # address, which exists only once the backend is Running. The target
      # wraps `tailscale wait` for exactly this. FreeBind= cannot cover the
      # race: it exists only for [Socket] units, and AdGuard binds its own
      # sockets directly.
      after = [
        "network.target"
        "tailscale-online.target"
      ];
      wants = [
        "tailscale-online.target"
      ];
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = lib.mkForce "adguardhome";
        Group = lib.mkForce "adguardhome";
        Restart = lib.mkForce "on-failure";
        RestartSec = lib.mkForce "5s";
      };
    };

    # The admin interface has no users by default, which leaves the whole
    # /control API unauthenticated. AdGuard's 0.107 API has no user endpoint,
    # so the password is written into the YAML. This runs as root before the
    # daemon: yq's in-place write chowns its temp file, and that syscall is
    # killed by the AdGuard service's seccomp sandbox when run from preStart.
    systemd.services.adguardhome-admin = {
      description = "Set the AdGuard Home admin user from the sops password";
      before = ["adguardhome.service"];
      wantedBy = ["multi-user.target"];
      path = [
        pkgs.coreutils
        pkgs.mkpasswd
        pkgs.yq-go
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        file=/var/lib/AdGuardHome/AdGuardHome.yaml
        if [ ! -f "$file" ]; then
          # Fresh install: the module's preStart creates the file on the first
          # boot; the next boot applies the password.
          exit 0
        fi
        password=$(cat ${config.sops.secrets."adguard/password".path})
        hash=$(mkpasswd -m bcrypt -R 10 "$password")
        HASH="$hash" yq -i '.users = [{"name": "admin", "password": strenv(HASH)}]' "$file"
        chown adguardhome:adguardhome "$file"
        chmod 0600 "$file"
      '';
    };

    # Port 53 is served directly by AdGuard Home for LAN clients.
    networking.firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/AdGuardHome 0750 adguardhome adguardhome -"
    ];

    environment.persistence."/per".directories = [
      "/var/lib/AdGuardHome"
    ];

    # Prometheus exporter: AdGuard 0.107 (nixpkgs's latest) has no native
    # /metrics endpoint, so scrape the REST API via adguard-exporter.
    users.users.adguard-exporter = {
      isSystemUser = true;
      group = "adguard-exporter";
    };
    users.groups.adguard-exporter = {};

    sops.secrets."adguard/password" = {
      owner = "adguard-exporter";
    };
    sops.templates."adguard-exporter-env" = {
      content = ''
        ADGUARD_SERVERS=http://127.0.0.1:${toString cfg.port}
        ADGUARD_USERNAMES=admin
        ADGUARD_PASSWORDS=${config.sops.placeholder."adguard/password"}
        PORT=${toString cfg.exporterPort}
        INTERVAL=30s
      '';
      owner = "adguard-exporter";
      group = "adguard-exporter";
      mode = "0400";
    };

    systemd.services.adguard-exporter = {
      description = "AdGuard Home Prometheus exporter";
      after = ["adguardhome.service"];
      wants = ["adguardhome.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        User = "adguard-exporter";
        Group = "adguard-exporter";
        EnvironmentFile = config.sops.templates."adguard-exporter-env".path;
        Restart = "on-failure";
        RestartSec = "5s";
      };
      script = ''
        exec ${inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.adguard-exporter}/bin/adguard-exporter
      '';
    };
  };
}
