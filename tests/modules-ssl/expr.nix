# Test: SSL module produces expected configuration across all hosts
{flake, ...}: let
  configs = flake.nixosConfigurations;

  # Common SSL assertions for any host config
  testSsl = hostName: config: {
    inherit hostName;

    # Module is enabled (default = true, should never be disabled)
    ssl_enabled = config.modules.system.ssl.enable;

    # Certificate bundle path environment variables are set and point to ca-bundle.crt
    ssl_cert_file_is_bundle = builtins.match ".*ca-bundle.crt" (config.environment.variables.SSL_CERT_FILE or "") != null;
    ssl_cert_dir_is_standard = config.environment.variables.SSL_CERT_DIR == "/etc/ssl/certs";
    curl_ca_bundle_is_bundle = builtins.match ".*ca-bundle.crt" (config.environment.variables.CURL_CA_BUNDLE or "") != null;

    # Nix daemon has SSL configured
    nix_ssl_cert_file_set = (config.nix.settings.ssl-cert-file or null) != null;

    # cacert package is in system packages (package is named nss-cacert)
    has_cacert_package = builtins.any (pkg: builtins.match ".*cacert.*" (pkg.name or "") != null) config.environment.systemPackages;
  };
in {
  desktop = testSsl "desktop" configs.desktop.config;
  portable = testSsl "portable" configs.portable.config;
  surface = testSsl "surface" configs.surface.config;
  hp-probook-vmware = testSsl "hp-probook-vmware" configs.hp-probook-vmware.config;
  hp-probook-wsl = testSsl "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q = testSsl "m920q" configs.m920q.config;
}
