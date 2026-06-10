# Test: maintenance module produces expected configuration
{flake, ...}: let
  # Get the desktop config (which has maintenance enabled with auto-update) from the flake
  inherit (flake.nixosConfigurations.desktop) config;
in {
  # Test: Maintenance module is enabled
  maintenance_enabled = config.modules.system.maintenance.enable;

  # Test: Auto-update is enabled on desktop
  auto_update_enabled = config.modules.system.maintenance.autoUpdate.enable;

  # Test: Monitoring is enabled
  monitoring_enabled = config.modules.system.maintenance.monitoring.enable;

  # Test: Alerts are enabled on desktop
  alerts_enabled = config.modules.system.maintenance.monitoring.alerts;

  # Test: Auto-update service exists when enabled
  has_auto_update_service = builtins.hasAttr "nixos-auto-update" config.systemd.services;
  auto_update_service_type = config.systemd.services.nixos-auto-update.serviceConfig.Type or null;

  # Test: Health check service exists when monitoring enabled
  has_health_check_service = builtins.hasAttr "system-health-check" config.systemd.services;
  health_check_service_type = config.systemd.services.system-health-check.serviceConfig.Type or null;

  # Test: Timers exist for periodic execution
  has_auto_update_timer = builtins.hasAttr "nixos-auto-update" config.systemd.timers;
  has_health_check_timer = builtins.hasAttr "system-health-check" config.systemd.timers;
}
