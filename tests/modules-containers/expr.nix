# Test: containers module produces expected configuration
{flake, ...}: let
  # Get the hp-probook-wsl config (which has containers enabled) from the flake
  inherit (flake.nixosConfigurations.hp-probook-wsl) config;
in {
  # Test: Containers module is enabled
  containers_enabled = config.modules.system.containers.enable;

  # Test: Docker is enabled
  docker_enabled = config.virtualisation.docker.enable;
  docker_on_boot = config.virtualisation.docker.enableOnBoot;

  # Test: Docker daemon settings configured
  has_storage_driver = config.virtualisation.docker.daemon.settings.storage-driver or null;
  has_log_driver = config.virtualisation.docker.daemon.settings.log-driver or null;
  has_dns = builtins.isList (config.virtualisation.docker.daemon.settings.dns or null);

  # Test: SSL certificates configured for Docker
  docker_ssl_cert = config.systemd.services.docker.environment.SSL_CERT_FILE or null;
  docker_curl_ca = config.systemd.services.docker.environment.CURL_CA_BUNDLE or null;

  # Test: Nix SSL certificate file set
  nix_ssl_cert = config.nix.settings.ssl-cert-file or null;
}
