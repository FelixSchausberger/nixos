# Test: wsl-integration module produces expected configuration
{flake, ...}: let
  # Get the hp-probook-wsl config (which has wsl-integration enabled) from the flake
  inherit (flake.nixosConfigurations.hp-probook-wsl) config;
in {
  # Test: WSL integration module is enabled
  wsl_integration_enabled = config.modules.system.wsl-integration.enable;

  # Test: WSL certificate setup service exists
  has_wsl_cert_service = builtins.hasAttr "wsl-cert-setup" config.systemd.services;

  # Test: Service is configured correctly
  service_description = config.systemd.services.wsl-cert-setup.description or null;
  service_type = config.systemd.services.wsl-cert-setup.serviceConfig.Type or null;
  service_user = config.systemd.services.wsl-cert-setup.serviceConfig.User or null;

  # Test: Service has required dependencies
  service_after = builtins.isList (config.systemd.services.wsl-cert-setup.after or null);
  service_wanted_by = builtins.isList (config.systemd.services.wsl-cert-setup.wantedBy or null);
}
