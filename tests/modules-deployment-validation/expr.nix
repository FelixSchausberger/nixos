# Test: deployment-validation module produces expected configuration
{flake, ...}: let
  # Get configuration with deployment validation enabled
  inherit (flake.nixosConfigurations.hp-probook-wsl) config;
  hasDeploymentValidation = config.modules.system ? deploymentValidation;
in {
  # Test: Deployment validation option exists
  has_deployment_validation_option = hasDeploymentValidation;

  # Test: Deployment validation is enabled by default (if option exists)
  deployment_validation_enabled =
    if hasDeploymentValidation
    then config.modules.system.deploymentValidation.enable
    else false;

  # Test: Pre-activation checks are enabled (if option exists)
  pre_activation_enabled =
    if hasDeploymentValidation
    then config.modules.system.deploymentValidation.preActivation.enable
    else false;

  # Test: Post-activation checks are enabled (if option exists)
  post_activation_enabled =
    if hasDeploymentValidation
    then config.modules.system.deploymentValidation.postActivation.enable
    else false;

  # Test: Activation script exists
  has_activation_script = builtins.hasAttr "deploymentValidation" config.system.activationScripts;

  # Test: Smoke test service exists
  has_smoke_test_service = builtins.hasAttr "post-activation-smoke-test" config.systemd.services;
  smoke_test_service_type = config.systemd.services.post-activation-smoke-test.serviceConfig.Type or null;

  # Test: validate-system utility is installed
  has_validate_system_package = builtins.any (pkg: pkg.name or "" == "validate-system") config.environment.systemPackages;

  # Test: Essential paths are configured (if option exists)
  essential_paths_configured =
    if hasDeploymentValidation
    then config.modules.system.deploymentValidation.essentialPaths != []
    else false;
  essential_paths_count =
    if hasDeploymentValidation
    then builtins.length config.modules.system.deploymentValidation.essentialPaths
    else 0;

  # Test: Critical services are configured (if option exists)
  critical_services_configured =
    if hasDeploymentValidation
    then config.modules.system.deploymentValidation.criticalServices != []
    else false;
  critical_services_count =
    if hasDeploymentValidation
    then builtins.length config.modules.system.deploymentValidation.criticalServices
    else 0;

  # Test: Timeout is configured (if option exists)
  smoke_test_timeout =
    if hasDeploymentValidation
    then config.modules.system.deploymentValidation.postActivation.timeout
    else 0;
}
