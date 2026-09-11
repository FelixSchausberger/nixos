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

  # GLideN64 renders fullscreen at its configured resolution (640x480 default)
  # without scaling to the window, so N64 tiles must route through the
  # resolution-setting wrapper instead of calling RMG directly
  fzero_x_uses_rmg_wrapper = let
    tile =
      builtins.head
      (builtins.filter (app: app.title == "F-Zero X") config.services.moonshine.settings.application);
  in
    builtins.any (arg: builtins.match ".*rmg-moonshine.*" arg != null) tile.command;

  # Dolphin has no --fullscreen flag and its stored config launches windowed,
  # so the GameCube tiles must force fullscreen through the config override.
  # The Moonshine compositor only auto-fills Steam windows.
  fzero_gx_forces_fullscreen = let
    tile =
      builtins.head
      (builtins.filter (app: app.title == "F-Zero GX") config.services.moonshine.settings.application);
  in
    builtins.elem "Dolphin.Display.Fullscreen=True" tile.command;

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

  # Vitals parity with m920q, in GUI mode (user daemon on
  # graphical-session.target instead of default.target)
  vitals_enabled = config.services.vitals.enable;
  vitals_gui_mode = !config.services.vitals.headless;
  vitals_daemon_gui_target =
    builtins.elem "graphical-session.target"
    config.home-manager.users.schausberger.systemd.user.services.vitals-daemon.Unit.After;
}
