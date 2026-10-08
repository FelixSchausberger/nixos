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

  # Test: headless profile — GUI stack stays in the closure, no display
  # manager starts a session at boot, the session comes up on demand
  auto_start_session = config.hostConfig.autoStartSession;
  session_on_demand_enabled = config.modules.system.sessionOnDemand.enable;
  # The desktop keeps its desktop application set despite on-demand sessions
  gui_apps = config.hostConfig.guiApps;
  greetd_disabled = !config.services.greetd.enable;
  # Single-compositor guarantee: niri.service owns the session, not UWSM
  uwsm_disabled = !config.programs.uwsm.enable;

  # Test: assertion quality gates are present for enabled desktop modules
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

  # GLideN64 renders fullscreen at its configured resolution (640x480 default)
  # without scaling to the window, so N64 tiles must route through the
  # resolution-setting wrapper instead of calling RMG directly
  fzero_x_uses_rmg_wrapper = let
    tile =
      builtins.head
      (builtins.filter (app: app.title == "F-Zero X") config.services.moonshine.settings.application);
  in
    builtins.any (arg: builtins.match ".*rmg-moonshine.*" arg != null) tile.command;

  # Moonshine's compositor only force-fills windows that carry a Steam app id,
  # so a non-Steam emulator's X11 fullscreen request is acknowledged without a
  # resize. GameCube tiles route through the gamescope wrapper, which provides
  # a real compositor for the fullscreen request, and still force Dolphin's
  # fullscreen through the config override so it renders at the client
  # resolution inside gamescope's output.
  fzero_gx_uses_gamescope = let
    tile =
      builtins.head
      (builtins.filter (app: app.title == "F-Zero GX") config.services.moonshine.settings.application);
  in
    builtins.any (arg: builtins.match ".*gamescope-moonshine.*" arg != null) tile.command;

  fzero_gx_forces_fullscreen = let
    tile =
      builtins.head
      (builtins.filter (app: app.title == "F-Zero GX") config.services.moonshine.settings.application);
  in
    builtins.elem "Dolphin.Display.Fullscreen=True" tile.command;

  # Every non-Steam emulator tile must fill the stream via the gamescope
  # wrapper; RMG keeps its dedicated GLideN64 resolution wrapper instead.
  emulator_tiles_use_gamescope = let
    tileFor = title: builtins.head (builtins.filter (app: app.title == title) config.services.moonshine.settings.application);
    usesGamescope = title: builtins.any (arg: builtins.match ".*gamescope-moonshine.*" arg != null) (tileFor title).command;
  in
    builtins.all usesGamescope [
      "F-Zero GX"
      "F-Zero"
      "Mario Kart 8 Deluxe"
    ];

  # snes9x's X11 fullscreen path only scales when the Xvideo path is enabled;
  # without it the SNES image is drawn at a fixed 2x centered in the output.
  fzero_snes_uses_xvideo = let
    tile =
      builtins.head
      (builtins.filter (app: app.title == "F-Zero") config.services.moonshine.settings.application);
  in
    builtins.elem "-xvideo" tile.command;

  # Every console ROM tile must ship box art for the Moonlight app grid.
  rom_tiles_have_boxart = let
    tileFor = title: builtins.head (builtins.filter (app: app.title == title) config.services.moonshine.settings.application);
    hasBoxart = title: ((tileFor title).boxart or null) != null;
  in
    builtins.all hasBoxart [
      "F-Zero GX"
      "Zelda Collector's Edition"
      "Zelda Wind Waker"
      "Super Monkey Ball"
      "Pokemon Stadium"
      "F-Zero X"
      "F-Zero"
      "Zelda A Link to the Past"
    ];

  # Vitals parity with m920q, in headless mode: the user daemon binds
  # default.target because graphical-session.target only exists while an
  # on-demand session runs.
  vitals_enabled = config.services.vitals.enable;
  vitals_headless = config.services.vitals.headless;
  vitals_daemon_default_target =
    builtins.elem "default.target"
    config.home-manager.users.schausberger.systemd.user.services.vitals-daemon.Unit.After;

  # Test: node exporter for the m920q scrape (job "node-desktop"), and the
  # RAPL mode fix that lets its built-in rapl collector read energy_uj
  node_exporter_enabled = config.services.prometheus.exporters.node.enable;
  rapl_energy_readable =
    builtins.any (rule: builtins.match ".*energy_uj.*" rule != null)
    config.systemd.tmpfiles.rules;
}
