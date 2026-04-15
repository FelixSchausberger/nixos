# Test: wsl-integration module produces expected configuration
{flake, ...}: let
  # Get the hp-probook-wsl config (which has wsl-integration enabled) from the flake
  inherit (flake.nixosConfigurations.hp-probook-wsl) config;
in {
  # Test: WSL integration module is enabled
  wsl_integration_enabled = config.modules.system.wsl-integration.enable;

  # Test: WSL certificate refresh service exists
  has_wsl_cert_service = builtins.hasAttr "wsl-cert-refresh" config.systemd.services;

  # Test: Service is configured correctly
  service_description = config.systemd.services.wsl-cert-refresh.description or null;
  service_type = config.systemd.services.wsl-cert-refresh.serviceConfig.Type or null;
  service_user = config.systemd.services.wsl-cert-refresh.serviceConfig.User or null;

  # Test: Service has required dependencies
  service_after = builtins.isList (config.systemd.services.wsl-cert-refresh.after or null);
  service_wanted_by = builtins.isList (config.systemd.timers.wsl-cert-refresh.wantedBy or null);
}
