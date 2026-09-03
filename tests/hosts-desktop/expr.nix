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
  monitoring_enabled = config.modules.system.maintenance.monitoring.enable;
  alerts_enabled = config.modules.system.maintenance.monitoring.alerts;

  # Test: assertion quality gates are present for enabled desktop modules
  has_display_manager_gui_assertion = hasAssertionWithMessage "display-manager.nix requires hostConfig.isGui = true when hostConfig.wms is non-empty";

  # Moonshine replaces Sunshine — no GUI assertions needed (Moonshine is headless-first)
  has_gaming_gui_assertion = hasAssertionWithMessage "modules.system.gaming.enable requires hostConfig.isGui = true";
  has_steam_gamemode_assertion = hasAssertionWithMessage "modules.system.steam.enable requires programs.gamemode.enable for GAMEMODERUN integration";

  # Moonshine XWayland socket guard (Sep 2026: every session failed with
  # "Could not find a free socket for the XServer" because persistence.nix
  # neuters the /tmp tmpfiles rule; the unit must create /tmp/.X11-unix
  # itself via ExecStartPre on every start)
  moonshine_x11_socket_guard =
    builtins.any
    (cmd: builtins.match ".*/tmp/.X11-unix" cmd != null)
    config.systemd.services.moonshine.serviceConfig.ExecStartPre;

  # Vitals parity with m920q, in GUI mode (user daemon on
  # graphical-session.target instead of default.target)
  vitals_enabled = config.services.vitals.enable;
  vitals_gui_mode = !config.services.vitals.headless;
  vitals_daemon_gui_target =
    builtins.elem "graphical-session.target"
    config.home-manager.users.schausberger.systemd.user.services.vitals-daemon.Unit.After;
}
