{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  options.modules.system.homelab.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home DNS ad-blocker";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Admin UI HTTP port";
    };
    exporterPort = lib.mkOption {
      type = lib.types.port;
      default = 9618;
      description = "Prometheus exporter HTTP port (localhost only)";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for DNS (53 TCP/UDP) and admin UI";
    };
  };

  config = lib.mkIf config.modules.system.homelab.adguardhome.enable {
    assertions = [
      {
        assertion = config.modules.system.homelab.adguardhome.port != 53;
        message = "AdGuard Home admin UI port must not be 53 (reserved for DNS service)";
      }
      {
        assertion =
          !config.modules.system.homelab.monitoring.enable
          || config.modules.system.homelab.adguardhome.port
          != config.modules.system.homelab.monitoring.grafanaPort;
        message = "AdGuard Home admin UI port must differ from Grafana port when monitoring is enabled";
      }
    ];

    # AdGuard directly serves LAN clients on port 53 (IPv4).
    # systemd-resolved handles local m920q resolution and IPv6 LAN DNS,
    # forwarding to AdGuard on 127.0.0.1:53.
    # FallbackDNS kicks in for the m920q itself when AdGuard is unreachable.
    services.resolved.settings.Resolve = {
      DNS = "127.0.0.1:53";
      FallbackDNS = "1.1.1.1 9.9.9.9";
      DNSStubListenerExtra = "fd50:5bc:d390:0:ea6a:64ff:fe9f:a050";
    };

    services.adguardhome = {
      enable = true;
      inherit (config.modules.system.homelab.adguardhome) openFirewall;
      settings = {
        # Admin UI port — migrate to 80/443 via Caddy after initial setup
        http.address = "0.0.0.0:${toString config.modules.system.homelab.adguardhome.port}";
        dns = {
          upstream_dns = [
            "https://dns.cloudflare.com/dns-query"
            "https://dns.quad9.net/dns-query"
          ];
          bootstrap_dns = [
            "9.9.9.9"
            "1.1.1.1"
          ];
          # Tailnet IP exposes AdGuard to roaming Tailscale clients, which use it
          # as the tailnet DNS server with public resolvers as fallback.
          bind_hosts = ["127.0.0.1" "192.168.178.2" "100.105.37.12"];
          port = 53;
        };
        querylog.enabled = true;
        querylog.interval = "7d";
        querylog.size_memory = 1000;
        filtering.response_ttl_secs = 86400;
        caching = {
          enabled = true;
          ttl_min_secs = 300;
          ttl_max_secs = 86400;
          size = 524288;
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
    systemd.services.adguardhome.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "adguardhome";
      Group = lib.mkForce "adguardhome";
      Restart = lib.mkForce "on-failure";
      RestartSec = lib.mkForce "5s";
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
        ADGUARD_SERVERS=http://127.0.0.1:${toString config.modules.system.homelab.adguardhome.port}
        ADGUARD_USERNAMES=admin
        ADGUARD_PASSWORDS=${config.sops.placeholder."adguard/password"}
        PORT=${toString config.modules.system.homelab.adguardhome.exporterPort}
        INTERVAL=30s
      '';
      owner = "adguard-exporter";
      group = "adguard-exporter";
      mode = "0400";
    };

    systemd.services.adguard-exporter = {
      description = "AdGuard Home Prometheus exporter";
      after = ["adguardhome.service" "sops-nix.service"];
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
