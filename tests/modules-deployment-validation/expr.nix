# Test: deployment-validation module produces expected configuration
{flake, ...}: let
  # Get configuration with deployment validation enabled
  inherit (flake.nixosConfigurations.hp-probook-wsl) config;
  cfg = config.modules.system.deploymentValidation;
in {
  # Test: Deployment validation option exists and is enabled by default
  has_deployment_validation_option = config.modules.system ? deploymentValidation;
  deployment_validation_enabled = cfg.enable;

  # Test: Critical services are configured
  critical_services_configured = cfg.criticalServices != [];
  critical_services_count = builtins.length cfg.criticalServices;

  # Test: An eval-time assertion guards the critical services
  has_critical_service_assertion =
    builtins.any (
      assertion: builtins.match ".*critical services missing.*" assertion.message != null
    )
    config.assertions;

  # Test: validate-system utility is installed
  has_validate_system_package = builtins.any (pkg: pkg.name or "" == "validate-system") config.environment.systemPackages;
}
