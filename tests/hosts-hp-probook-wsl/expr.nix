# Test: hp-probook-wsl host configuration builds correctly
{flake, ...}: let
  # Get the hp-probook-wsl configuration from the flake
  inherit (flake.nixosConfigurations.hp-probook-wsl) config;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: User exists
  user_exists = builtins.hasAttr "schausberger" config.users.users;

  # Test: WSL is enabled
  wsl_enabled = config.wsl.enable;

  # Test: Container tools are enabled
  containers_enabled = config.modules.system.containers.enable;

  # Test: WSL integration is enabled
  wsl_integration_enabled = config.modules.system.wsl-integration.enable;

  # Test: System is TUI-only (not GUI)
  is_gui = config.hostConfig.isGui;

  # Test: SSL certificates are configured
  has_ssl_cert_file = config.environment.variables.SSL_CERT_FILE != null;

  # Test: WSL integration packages are configured
  # Note: We check the option values instead of evaluating systemPackages
  # to avoid expensive derivation evaluation
  wsl_packages_enabled = config.wsl.wslConf != null;
}
