# Centralized SSL/TLS certificate configuration
# Provides reusable SSL configuration for system and services
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.ssl;
in {
  options.modules.system.ssl = {
    enable = lib.mkEnableOption "Centralized SSL/TLS configuration" // {default = true;};

    # Bundle configuration
    bundle = {
      standard = lib.mkOption {
        type = lib.types.path;
        default = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        description = "Path to standard CA certificate bundle";
      };

      useEnhanced = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to add missing intermediate certificates to system CA store";
      };
    };

    # Helper functions for use in other modules
    helpers = {
      nixDaemonEnv = lib.mkOption {
        type = lib.types.attrs;
        description = "SSL environment variables for nix-daemon (with mkForce)";
        readOnly = true;
      };

      dockerEnv = lib.mkOption {
        type = lib.types.attrs;
        description = "SSL environment variables for Docker service";
        readOnly = true;
      };

      standardEnv = lib.mkOption {
        type = lib.types.attrs;
        description = "Standard SSL environment variables";
        readOnly = true;
      };

      bundlePath = lib.mkOption {
        type = lib.types.str;
        description = "Active certificate bundle path";
        readOnly = true;
      };

      dockerCertSetup = lib.mkOption {
        type = lib.types.str;
        description = "Docker certificate setup and validation script";
        readOnly = true;
      };
    };
  };

  config = let
    # Select bundle - use merged bundle from security.pki when enhanced is enabled
    # security.pki creates the merged bundle at /etc/pki/tls/certs/ca-bundle.crt
    bundlePath =
      if cfg.bundle.useEnhanced
      then "/etc/pki/tls/certs/ca-bundle.crt"
      else cfg.bundle.standard;

    # Missing intermediate certificates from authoritative sources via AIA
    # GlobalSign Atlas R3 DV TLS CA 2025 Q3: http://secure.globalsign.com/cacert/gsatlasr3dvtlsca2025q3.crt
    globalSignAtlasR3 = ''
      -----BEGIN CERTIFICATE-----
      MIIEkDCCA3igAwIBAgIRAINDHEQNtND3hnr+fDpTzC0wDQYJKoZIhvcNAQELBQAw
      TDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjMxEzARBgNVBAoTCkds
      b2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMjUwNDE2MDMxNDA2WhcN
      MjcwNDE2MDAwMDAwWjBYMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2ln
      biBudi1zYTEuMCwGA1UEAxMlR2xvYmFsU2lnbiBBdGxhcyBSMyBEViBUTFMgQ0Eg
      MjAyNSBRMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJl+DVGOJAAP
      yvBV3WNzOyQ9MA5DkZQ3i7bz8kRC4o0lscsWm8nQNo33wt7o2IcKcG9LoV39TPA3
      JSpc/+PSmF5dtST3Znwh4srbjw6+Xb7AESRDyK/2+ib++2HusenVY0ofsyoW4RWX
      UGgoA5DjLSct2bofJRAk2JTLbFzrOQcBcFbTlYQ6VDZd/59kyUEma2SZz66A9YCO
      iGNSddpq4WRrZdppIEJGGrk55WkGxQfbuBINh0axbG2lzmu18Eb21VI48pWJVKGS
      MGAE2ncMeNeIECnIEj7gZTHowKCmeFMd91z0RxnB1vNz5un7zBNVQqp5izQbnzp3
      oinHKcXhZJMCAwEAAaOCAV8wggFbMA4GA1UdDwEB/wQEAwIBhjAdBgNVHSUEFjAU
      BggrBgEFBQcDAQYIKwYBBQUHAwIwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4E
      FgQU07znV4LmwGOWuL1OawC2X6Pv/t8wHwYDVR0jBBgwFoAUj/BLf6guRSSuTVD6
      Y5qL3uLdG7wwewYIKwYBBQUHAQEEbzBtMC4GCCsGAQUFBzABhiJodHRwOi8vb2Nz
      cDIuZ2xvYmFsc2lnbi5jb20vcm9vdHIzMDsGCCsGAQUFBzAChi9odHRwOi8vc2Vj
      dXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9yb290LXIzLmNydDA2BgNVHR8ELzAt
      MCugKaAnhiVodHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL3Jvb3QtcjMuY3JsMCEG
      A1UdIAQaMBgwCAYGZ4EMAQIBMAwGCisGAQQBoDIKAQMwDQYJKoZIhvcNAQELBQAD
      ggEBAKFebd4Rsi18w7eYYN1p/3LvdqIkARD/vlgBa7DRpn2LC3lOX9hGBGOxRhuL
      EJoHp2QrkICqbmKiuZbi4xFgdSa1qc3vpWTtJax6oY6n+9yP9qfv/lkeB/R28Ob5
      JIeBYHMZ5b7I2+YMvggutFvu9x6WBHIBYzUxl+wFZH2exzp6xHliz+nXYLRO9sZt
      Zi/hw/hwMsYJCjkZHJuUL3F6l5vfUJfvzNKfab/bDsLK7OphxEpongoQHhW6ZoOP
      /h31IY5TfMqABCw4CahlRtx8nXqxHFxKcj4Yr5mQdxNmKSEIsOhey2kmL2gKRggM
      CNdMwCuKKznspqw80Hzuu39a6AU=
      -----END CERTIFICATE-----
    '';

    # Google Trust Services WE1: http://i.pki.goog/we1.crt
    googleTrustWE1 = ''
      -----BEGIN CERTIFICATE-----
      MIICjjCCAjOgAwIBAgIQf/NXaJvCTjAtkOGKQb0OHzAKBggqhkjOPQQDAjBQMSQw
      IgYDVQQLExtHbG9iYWxTaWduIEVDQyBSb290IENBIC0gUjQxEzARBgNVBAoTCkds
      b2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMjMxMjEzMDkwMDAwWhcN
      MjkwMjIwMTQwMDAwWjA7MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVR29vZ2xlIFRy
      dXN0IFNlcnZpY2VzMQwwCgYDVQQDEwNXRTEwWTATBgcqhkjOPQIBBggqhkjOPQMB
      BwNCAARvzTr+Z1dHTCEDhUDCR127WEcPQMFcF4XGGTfn1XzthkubgdnXGhOlCgP4
      mMTG6J7/EFmPLCaY9eYmJbsPAvpWo4IBAjCB/zAOBgNVHQ8BAf8EBAMCAYYwHQYD
      VR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMBIGA1UdEwEB/wQIMAYBAf8CAQAw
      HQYDVR0OBBYEFJB3kjVnxP+ozKnme9mAeXvMk/k4MB8GA1UdIwQYMBaAFFSwe61F
      uOJAf/sKbvu+M8k8o4TVMDYGCCsGAQUFBwEBBCowKDAmBggrBgEFBQcwAoYaaHR0
      cDovL2kucGtpLmdvb2cvZ3NyNC5jcnQwLQYDVR0fBCYwJDAioCCgHoYcaHR0cDov
      L2MucGtpLmdvb2cvci9nc3I0LmNybDATBgNVHSAEDDAKMAgGBmeBDAECATAKBggq
      hkjOPQQDAgNJADBGAiEAokJL0LgR6SOLR02WWxccAq3ndXp4EMRveXMUVUxMWSMC
      IQDspFWa3fj7nLgouSdkcPy1SdOR2AGm9OQWs7veyXsBwA==
      -----END CERTIFICATE-----
    '';

    # Sectigo ECC Domain Validation Secure Server CA
    # Extracted from api.github.com TLS handshake
    sectigoEccDv = ''
      -----BEGIN CERTIFICATE-----
      MIIDqDCCAy6gAwIBAgIRAPNkTmtuAFAjfglGvXvh9R0wCgYIKoZIzj0EAwMwgYgx
      CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJz
      ZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQD
      EyVVU0VSVHJ1c3QgRUNDIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTE4MTEw
      MjAwMDAwMFoXDTMwMTIzMTIzNTk1OVowgY8xCzAJBgNVBAYTAkdCMRswGQYDVQQI
      ExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoT
      D1NlY3RpZ28gTGltaXRlZDE3MDUGA1UEAxMuU2VjdGlnbyBFQ0MgRG9tYWluIFZh
      bGlkYXRpb24gU2VjdXJlIFNlcnZlciBDQTBZMBMGByqGSM49AgEGCCqGSM49AwEH
      A0IABHkYk8qfbZ5sVwAjBTcLXw9YWsTef1Wj6R7W2SUKiKAgSh16TwUwimNJE4xk
      IQeV/To14UrOkPAY9z2vaKb71EijggFuMIIBajAfBgNVHSMEGDAWgBQ64QmG1M8Z
      wpZ2dEl23OA1xmNjmjAdBgNVHQ4EFgQU9oUKOxGG4QR9DqoLLNLuzGR7e64wDgYD
      VR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0lBBYwFAYIKwYB
      BQUHAwEGCCsGAQUFBwMCMBsGA1UdIAQUMBIwBgYEVR0gADAIBgZngQwBAgEwUAYD
      VR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVz
      dEVDQ0NlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEBBGowaDA/
      BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdEVD
      Q0FkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2VydHJ1
      c3QuY29tMAoGCCqGSM49BAMDA2gAMGUCMEvnx3FcsVwJbZpCYF9z6fDWJtS1UVRs
      cS0chWBNKPFNpvDKdrdKRe+oAkr2jU+ubgIxAODheSr2XhcA7oz9HmedGdMhlrd9
      4ToKFbZl+/OnFFzqnvOhcjHvClECEQcKmc8fmA==
      -----END CERTIFICATE-----
    '';

    # Common SSL environment variables
    sslEnvVars = {
      SSL_CERT_FILE = bundlePath;
      SSL_CERT_DIR = "/etc/ssl/certs";
      CURL_CA_BUNDLE = bundlePath;
      NIX_SSL_CERT_FILE = bundlePath;
      GIT_SSL_CAINFO = bundlePath;
      NODE_EXTRA_CA_CERTS = bundlePath;
    };

    # Docker-specific SSL environment variables (Go-based)
    dockerEnvVars =
      sslEnvVars
      // {
        CA_BUNDLE = bundlePath;
        GOCERTIFI_CAFILE = bundlePath;
        GO_CERTS_FILE = bundlePath;
        REQUESTS_CA_BUNDLE = bundlePath;
        CERT_FILE = bundlePath;
        GODEBUG = "x509ignoreCN=0,tls13=1";
      };
  in
    lib.mkIf cfg.enable {
      # System-wide SSL certificate configuration
      security.pki.certificateFiles = [cfg.bundle.standard];

      # Add missing intermediate certificates to system CA store
      security.pki.certificates = lib.mkIf cfg.bundle.useEnhanced [
        globalSignAtlasR3
        googleTrustWE1
        sectigoEccDv
      ];

      # Ensure proper SSL certificate paths in /etc
      # When useEnhanced is false, explicitly set bundle paths
      # When useEnhanced is true, let security.pki create the merged bundle
      environment.etc = lib.mkIf (!cfg.bundle.useEnhanced) {
        "ssl/certs/ca-bundle.crt".source = lib.mkDefault cfg.bundle.standard;
        "ssl/certs/ca-certificates.crt".source = lib.mkDefault cfg.bundle.standard;
      };

      # System-wide SSL/TLS certificate environment variables
      environment.variables = lib.mapAttrs (_: lib.mkDefault) sslEnvVars;

      # Global session variables for all user sessions
      environment.sessionVariables = sslEnvVars;

      # Ensure cacert package is available
      environment.systemPackages = [pkgs.cacert];

      # Nix daemon SSL configuration
      nix.settings.ssl-cert-file = lib.mkDefault bundlePath;

      # Set helper values (available as config.modules.system.ssl.helpers.*)
      modules.system.ssl.helpers = {
        nixDaemonEnv = lib.mapAttrs (_: lib.mkForce) sslEnvVars;
        dockerEnv = dockerEnvVars;
        standardEnv = sslEnvVars;
        inherit bundlePath;
        dockerCertSetup = ''
          # Ensure certificate directories exist with proper permissions
          mkdir -p /etc/docker/certs.d/registry-1.docker.io
          mkdir -p /etc/docker/certs.d/index.docker.io
          mkdir -p /etc/docker/certs.d/docker.io

          # Link system certificates to Docker-specific locations
          ln -sf ${cfg.bundle.standard} /etc/docker/certs.d/registry-1.docker.io/ca.crt
          ln -sf ${cfg.bundle.standard} /etc/docker/certs.d/index.docker.io/ca.crt
          ln -sf ${cfg.bundle.standard} /etc/docker/certs.d/docker.io/ca.crt

          # Verify certificate bundle is readable
          if [ ! -r "${cfg.bundle.standard}" ]; then
            echo "Warning: Certificate bundle not readable at ${cfg.bundle.standard}"
          fi

          # Certificate bundle validation check
          echo "Validating certificate bundle integrity..."
          CERT_BUNDLE="${cfg.bundle.standard}"
          if [ -r "$CERT_BUNDLE" ]; then
            CERT_COUNT=$(grep -c 'BEGIN CERTIFICATE' "$CERT_BUNDLE")
            echo "✅ Certificate bundle readable with $CERT_COUNT certificates"

            # Check for expired certificates
            TEMP_DIR=$(mktemp -d)
            csplit -s -f "$TEMP_DIR/cert-" "$CERT_BUNDLE" '/-----BEGIN CERTIFICATE-----/' '{*}'
            EXPIRED_COUNT=0
            for cert_file in "$TEMP_DIR"/cert-*; do
              if [ -s "$cert_file" ] && grep -q 'BEGIN CERTIFICATE' "$cert_file"; then
                if ! ${pkgs.openssl}/bin/openssl x509 -in "$cert_file" -checkend 0 -noout 2>/dev/null; then
                  EXPIRED_COUNT=$((EXPIRED_COUNT + 1))
                fi
              fi
            done
            rm -rf "$TEMP_DIR"

            if [ "$EXPIRED_COUNT" -eq 0 ]; then
              echo "✅ No expired certificates found in bundle"
            else
              echo "⚠️  Warning: $EXPIRED_COUNT expired certificates found in bundle"
            fi
          else
            echo "❌ Certificate bundle not readable at $CERT_BUNDLE"
          fi
        '';
      };
    };
}
