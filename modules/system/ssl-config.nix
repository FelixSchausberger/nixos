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
    };

    # Helper functions for use in other modules
    helpers = {
      dockerEnv = lib.mkOption {
        type = lib.types.attrs;
        description = "SSL environment variables for Docker service";
        readOnly = true;
      };
    };
  };

  config = let
    bundlePath = cfg.bundle.standard;

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
      };
  in
    lib.mkIf cfg.enable {
      # System-wide SSL certificate configuration
      security.pki.certificateFiles = [cfg.bundle.standard];

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
        dockerEnv = dockerEnvVars;
      };
    };
}
