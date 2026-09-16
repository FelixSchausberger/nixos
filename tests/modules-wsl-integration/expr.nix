# Test: wsl-integration module produces expected configuration
{flake, ...}: let
  # Get the hp-probook-wsl config (which has wsl-integration enabled) from the flake
  inherit (flake.nixosConfigurations.hp-probook-wsl) config;
in {
  # Test: WSL integration module is enabled
  wsl_integration_enabled = config.modules.system.wsl-integration.enable;

  # The Windows certificate import chain was removed (dead end-to-end: no
  # consumer read its bundles); assert no cert service/timer remains.
  has_wsl_cert_service = builtins.hasAttr "wsl-cert-refresh" config.systemd.services;
  cert_timer_wanted_by = builtins.isList (config.systemd.timers.wsl-cert-refresh.wantedBy or null);

  # Test: journal stays volatile (WSL terminates without clean shutdown)
  journal_storage = config.services.journald.settings.Journal.Storage or null;
}
