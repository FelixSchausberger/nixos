# Test: desktop host configuration builds correctly
{flake, ...}: let
  # Get the desktop configuration from the flake
  inherit (flake.nixosConfigurations.desktop) config;

  hasAssertionWithMessage = message: builtins.any (assertion: (assertion.message or "") == message) config.assertions;

  # Tokens of a systemd argv list, for exact-argument checks.
  argvTokens = cmd:
    builtins.filter builtins.isString (
      builtins.split " " (builtins.concatStringsSep " " cmd)
    );

  # Matches a hook whose command vector ends up invoking `shutdown` (paths are
  # absolute because Moonshine resolves hook programs with `which` against the
  # unit PATH and silently drops unresolvable ones).
  hasShutdownHook = hooks:
    builtins.any
    (cmd: builtins.match ".*/shutdown.*" (builtins.concatStringsSep " " cmd) != null)
    hooks;
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

  # Moonshine XWayland socket dir (Sep 2026: every session failed with
  # "Could not find a free socket for the XServer"). The directory is created
  # by the system tmpfiles rule, which only works while the persistence
  # overrides leave /tmp in scope for the create phases.
  x11_socket_tmpfiles_rule =
    builtins.any
    (rule: builtins.match "d /tmp/.X11-unix .*" rule != null)
    config.systemd.tmpfiles.rules;

  # The rule only runs if the create-phase jobs leave /tmp in scope.
  tmpfiles_setup_keeps_tmp =
    !(
      builtins.elem "--exclude-prefix=/tmp" (
        argvTokens config.systemd.services.systemd-tmpfiles-setup.serviceConfig.ExecStart
      )
    );

  # Power hooks (modules.system.moonshine.powerOff): a stream start cancels a
  # pending power-off and a stream end schedules one. The commands must be
  # absolute paths (Moonshine resolves hook programs with `which` against the
  # unit PATH and silently drops unresolvable ones) and run through the
  # NOPASSWD sudo rule a headless host without a login session needs.
  moonshine_power_off_enabled = config.modules.system.moonshine.powerOff.enable;
  steam_tile_power_hooks = let
    tile = builtins.head (builtins.filter (app: app.title == "Steam") config.services.moonshine.settings.application);
  in
    hasShutdownHook tile.pre_command && hasShutdownHook tile.post_command;
  scanner_power_hooks = let
    scan = builtins.head config.services.moonshine.settings.application_scanner;
  in
    hasShutdownHook scan.pre_command && hasShutdownHook scan.post_command;
  desktop_shutdown_sudo_nopasswd =
    builtins.any
    (rule: builtins.any (cmd: cmd.command == "/run/current-system/sw/bin/shutdown" && builtins.elem "NOPASSWD" cmd.options) rule.commands)
    config.security.sudo.extraRules;
  # The hooks must call the setuid wrapper: the profile's sudo is the plain
  # package, refuses to start at all, and its failure aborts every launch
  # (2026-10-15: no tile started on the desktop until this was pinned).
  power_hooks_use_sudo_wrapper = let
    tile = builtins.head (builtins.filter (app: app.title == "Steam") config.services.moonshine.settings.application);
    usesWrapper = hooks: builtins.any (cmd: builtins.elem "${config.security.wrapperDir}/sudo" cmd) hooks;
  in
    usesWrapper tile.pre_command && usesWrapper tile.post_command;

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
  # The desktop runs no monitoring stack, so its score is exported through the
  # node exporter textfile collector that the m920q Prometheus already scrapes.
  vitals_textfile_enabled = config.services.vitals.textfile.enable;
  vitals_textfile_collector =
    builtins.any (flag: builtins.match "--collector.textfile.directory=.*" flag != null)
    config.services.prometheus.exporters.node.extraFlags;
  vitals_metrics_timer =
    builtins.elem "timers.target"
    config.systemd.timers."vitals-metrics".wantedBy;

  # Test: node exporter for the m920q scrape (job "node-desktop"), and the
  # udev rule that makes energy_uj readable so its built-in rapl collector
  # works (a tmpfiles chmod loses the boot race against the powercap device)
  node_exporter_enabled = config.services.prometheus.exporters.node.enable;
  rapl_energy_readable =
    builtins.any (line: builtins.match ".*energy_uj.*" line != null)
    (builtins.filter builtins.isString (builtins.split "\n" config.services.udev.extraRules));
}
