# Test: desktop host configuration builds correctly
{flake, ...}: let
  # Get the desktop configuration from the flake
  inherit (flake.nixosConfigurations.desktop) config;

  hasAssertionWithMessage = message: builtins.any (assertion: (assertion.message or "") == message) config.assertions;
in {
  # Test: Host name is set correctly
  hostname = config.networking.hostName;

  # Test: User exists
  user_exists = builtins.hasAttr "schausberger" config.users.users;

  # Test: System is GUI-enabled (desktop system)
  is_gui = config.hostConfig.isGui;

  # Test: Default window manager configuration
  wm_count = builtins.length config.hostConfig.wms;
  has_hyprland = builtins.elem "hyprland" config.hostConfig.wms;

  # Test: AMD GPU profile is enabled
  amd_gpu_enabled = config.hardware.profiles.amdGpu.enable;
  amd_gpu_variant = config.hardware.profiles.amdGpu.variant;

  # Test: QMK keyboard support enabled
  qmk_enabled = config.hardware.keyboard.qmk.enable;

  # Test: System maintenance configured
  maintenance_enabled = config.modules.system.maintenance.enable;
  auto_update_enabled = config.modules.system.maintenance.autoUpdate.enable;
  monitoring_enabled = config.modules.system.maintenance.monitoring.enable;
  alerts_enabled = config.modules.system.maintenance.monitoring.alerts;

  # Test: assertion quality gates are present for enabled desktop modules
  has_display_manager_gui_assertion = hasAssertionWithMessage "display-manager.nix requires hostConfig.isGui = true when hostConfig.wms is non-empty";
  has_sunshine_wms_assertion = hasAssertionWithMessage "modules.system.sunshine.enable requires a graphical session (hostConfig.wms must be non-empty)";
  has_sunshine_gui_assertion = hasAssertionWithMessage "modules.system.sunshine.enable requires hostConfig.isGui = true";
  has_gaming_gui_assertion = hasAssertionWithMessage "modules.system.gaming.enable requires hostConfig.isGui = true";
  has_steam_gamemode_assertion = hasAssertionWithMessage "modules.system.steam.enable requires programs.gamemode.enable for GAMEMODERUN integration";
}
