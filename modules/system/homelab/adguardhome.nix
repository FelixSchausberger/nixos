{
  config,
  lib,
  ...
}: {
  options.modules.system.homelab.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home DNS ad-blocker";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Admin UI HTTP port";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for DNS (53 TCP/UDP) and admin UI";
    };
  };

  config = lib.mkIf config.modules.system.homelab.adguardhome.enable {
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
          bootstrap_dns = ["9.9.9.9" "1.1.1.1"];
          bind_hosts = ["0.0.0.0"];
          port = 53;
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
    };

    # The nixpkgs openFirewall option only opens port 3000 (admin UI).
    # Port 53 must be opened explicitly for LAN DNS clients.
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
  };
}
