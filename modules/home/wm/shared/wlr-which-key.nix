{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.which-key;

  # Import keybind definitions
  keybindDefs = import ./keybind-definitions.nix {inherit lib;};

  # Helper to get terminal package for WM config
  getTerminalPkg = wmCfg:
    if wmCfg.terminal == "ghostty"
    then inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
    else if wmCfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if wmCfg.terminal == "wezterm"
    then pkgs.wezterm
    else inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Build which-key menu structure for a specific WM
  buildWhichKeyConfig = wmType: let
    isNiri = wmType == "niri";
    isHyprland = wmType == "hyprland";
    wmCfg =
      if isNiri
      then config.wm.niri
      else config.wm.hyprland;

    terminalPkg = getTerminalPkg wmCfg;
    terminalBin =
      if wmCfg.terminal == "ghostty"
      then "ghostty"
      else wmCfg.terminal;

    # Helper to extract just the key without modifiers
    stripModifiers = key: let
      parts = lib.splitString "+" key;
    in
      lib.toLower (lib.last parts);

    # Filter bindings based on WM
    filterBindings = bindings:
      lib.filterAttrs (name: bind:
        (!bind ? niriOnly || isNiri)
        && (!bind ? hyprlandOnly || isHyprland))
      bindings;

    # Convert directional action to submenu entry
    dirToSubmenu = actionName: actionCfg: dir: let
      dirKeys = keybindDefs.directions.${dir};
      dirLabel =
        if dir == "left"
        then "Left"
        else if dir == "right"
        then "Right"
        else if dir == "up"
        then "Up"
        else "Down";
    in {
      key = lib.toLower dirKeys.colemak;
      desc = "${lib.replaceStrings ["{direction}"] [dirLabel] actionCfg.desc} ${actionCfg.descNote}";
      cmd = "niri msg action ${actionName}-${dir}";
    };

    # Build navigation submenu with directional actions
    buildNavigationSubmenu = let
      actions = keybindDefs.categories.navigation.actions;
      # Generate entries for each direction for each action
      focusEntries =
        (lib.concatMap (dir: [
          (dirToSubmenu "focus-column" actions.focus dir)
        ]) ["left" "right"])
        ++ (lib.concatMap (dir: [
          (dirToSubmenu "focus-window" actions.focus dir)
        ]) ["down" "up"]);
      moveEntries =
        (lib.concatMap (dir: [
          (dirToSubmenu "move-column" actions.move dir)
        ]) ["left" "right"])
        ++ (lib.concatMap (dir: [
          (dirToSubmenu "move-window" actions.move dir)
        ]) ["down" "up"]);
      monitorFocusEntries = lib.concatMap (dir: [
        (dirToSubmenu "focus-monitor" actions.focus-monitor dir)
      ]) ["left" "down" "up" "right"];
      monitorMoveEntries = lib.concatMap (dir: [
        (dirToSubmenu "move-column-to-monitor" actions.move-monitor dir)
      ]) ["left" "down" "up" "right"];
    in
      focusEntries
      ++ moveEntries
      ++ monitorFocusEntries
      ++ monitorMoveEntries
      ++ (
        if isNiri
        then [
          {
            key = "Home";
            desc = "Focus First Column";
            cmd = "niri msg action focus-column-first";
          }
          {
            key = "End";
            desc = "Focus Last Column";
            cmd = "niri msg action focus-column-last";
          }
        ]
        else []
      );

    # Build category submenu from bindings
    buildCategorySubmenu = category: let
      bindings = filterBindings category.bindings;
    in
      lib.mapAttrsToList (name: bind: {
        key = stripModifiers bind.key;
        desc = bind.desc;
        cmd =
          if isNiri
          then
            (
              if name == "terminal"
              then "${terminalPkg}/bin/${terminalBin}"
              else if name == "terminal-safe"
              then "${terminalPkg}/bin/${terminalBin} -e ${pkgs.fish}/bin/fish -c 'set -gx ZELLIJ_AUTO_START 0; exec fish'"
              else if name == "launcher"
              then "walker"
              else if name == "close"
              then "niri msg action close-window"
              else if name == "float"
              then "niri msg action toggle-window-floating"
              else if name == "float-tiling"
              then "niri msg action switch-focus-between-floating-and-tiling"
              else if name == "fullscreen"
              then "niri msg action maximize-column"
              else if name == "fullscreen-window"
              then "niri msg action fullscreen-window"
              else if name == "center"
              then "niri msg action center-column"
              else if name == "center-visible"
              then "niri msg action center-visible-columns"
              else if name == "cycle-width"
              then "niri msg action switch-preset-column-width"
              else if name == "cycle-height"
              then "niri msg action switch-preset-window-height"
              else if name == "reset-height"
              then "niri msg action reset-window-height"
              else if name == "consume-left"
              then "niri msg action consume-or-expel-window-left"
              else if name == "consume-right"
              then "niri msg action consume-or-expel-window-right"
              else if name == "consume-into"
              then "niri msg action consume-window-into-column"
              else if name == "expel-from"
              then "niri msg action expel-window-from-column"
              else "true"
            )
          else
            (
              if name == "terminal"
              then "${terminalPkg}/bin/${terminalBin}"
              else if name == "launcher"
              then "walker"
              else if name == "browser"
              then wmCfg.browser
              else if name == "file-manager"
              then wmCfg.fileManager
              else if name == "editor"
              then "${pkgs.helix}/bin/hx"
              else if name == "close"
              then "hyprctl dispatch killactive"
              else if name == "float"
              then "hyprctl dispatch togglefloating"
              else "true"
            );
      })
      bindings;

    # Build main menu structure
    menu = lib.filter (item: item != null) (
      lib.mapAttrsToList (catName: category: let
        # Skip categories that are WM-specific
        skip =
          (category ? niriOnly && !isNiri)
          || (category ? hyprlandOnly && !isHyprland);
      in
        if skip
        then null
        else {
          key = category.key;
          desc = category.title;
          submenu =
            if catName == "navigation"
            then buildNavigationSubmenu
            else if catName == "scratchpads"
            then
              (lib.mapAttrsToList (name: bind: {
                  key = stripModifiers bind.key;
                  desc = bind.desc;
                  cmd = "${pkgs.pyprland}/bin/pypr toggle ${name}";
                })
                (filterBindings category.bindings))
            else if catName == "workspaces"
            then
              (lib.mapAttrsToList (name: bind: {
                  key = stripModifiers bind.key;
                  desc = bind.desc;
                  cmd =
                    if isNiri
                    then
                      (
                        if name == "prev"
                        then "niri msg action focus-workspace-up"
                        else if name == "next"
                        then "niri msg action focus-workspace-down"
                        else if name == "move-prev"
                        then "niri msg action move-column-to-workspace-up"
                        else if name == "move-next"
                        then "niri msg action move-column-to-workspace-down"
                        else if name == "shift-up"
                        then "niri msg action move-workspace-up"
                        else if name == "shift-down"
                        then "niri msg action move-workspace-down"
                        else if name == "prev-alt"
                        then "niri msg action focus-workspace-up"
                        else if name == "next-alt"
                        then "niri msg action focus-workspace-down"
                        else if name == "previous"
                        then "bash -c 'niri msg action toggle-overview 2>/dev/null & ironbar bar main toggle-visible 2>/dev/null & wait'"
                        else "true"
                      )
                    else
                      (
                        if name == "prev"
                        then "hyprctl dispatch workspace e-1"
                        else if name == "next"
                        then "hyprctl dispatch workspace e+1"
                        else if name == "move-prev"
                        then "hyprctl dispatch movetoworkspace e-1"
                        else if name == "move-next"
                        then "hyprctl dispatch movetoworkspace e+1"
                        else if name == "prev-alt"
                        then "hyprctl dispatch workspace e-1"
                        else if name == "next-alt"
                        then "hyprctl dispatch workspace e+1"
                        else if name == "previous"
                        then "hyprctl dispatch workspace previous"
                        else "true"
                      );
                })
                (filterBindings category.bindings))
            else if catName == "screenshots"
            then
              (lib.mapAttrsToList (name: bind: {
                  key = stripModifiers bind.key;
                  desc = bind.desc;
                  cmd =
                    if isNiri
                    then
                      (
                        if name == "selection"
                        then "niri msg action screenshot"
                        else if name == "fullscreen"
                        then "niri msg action screenshot-screen"
                        else if name == "window"
                        then "niri msg action screenshot-window"
                        else "true"
                      )
                    else
                      (
                        if name == "selection"
                        then "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy"
                        else if name == "fullscreen"
                        then "${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy"
                        else if name == "save-selection"
                        then "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png"
                        else if name == "save-fullscreen"
                        then "${pkgs.grim}/bin/grim ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png"
                        else "true"
                      );
                })
                (filterBindings category.bindings))
            else if catName == "system"
            then
              (lib.mapAttrsToList (name: bind: {
                  key = stripModifiers bind.key;
                  desc = bind.desc;
                  cmd =
                    if isNiri
                    then
                      (
                        if name == "lock"
                        then "loginctl lock-session"
                        else if name == "quit" || name == "quit-alt"
                        then "niri msg action quit"
                        else if name == "power-monitors"
                        then "niri msg action power-off-monitors"
                        else if name == "idle-inhibitor"
                        then "stasis-toggle"
                        else if name == "debug-tint"
                        then "niri msg action toggle-debug-tint"
                        else if name == "emergency"
                        then "${terminalPkg}/bin/${terminalBin} -e ${pkgs.bash}/bin/bash --norc -c 'touch /tmp/.nixos-emergency-mode && exec bash --norc'"
                        else if name == "overview"
                        then "bash -c 'niri msg action toggle-overview 2>/dev/null & ironbar bar main toggle-visible 2>/dev/null & wait'"
                        else "true"
                      )
                    else
                      (
                        if name == "lock"
                        then "loginctl lock-session"
                        else if name == "quit" || name == "quit-alt"
                        then "hyprctl dispatch exit"
                        else if name == "debug-tint"
                        then "${pkgs.libnotify}/bin/notify-send 'Test' 'Notification system'"
                        else if name == "emergency"
                        then "pkill -SIGUSR1 wired"
                        else "true"
                      );
                })
                (filterBindings category.bindings))
            else if catName == "utilities"
            then
              (lib.mapAttrsToList (name: bind: {
                  key = stripModifiers bind.key;
                  desc = bind.desc;
                  cmd =
                    if name == "clipboard"
                    then "${inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/walker --modules clipboard"
                    else if name == "emoji"
                    then "${inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/walker --modules emoji"
                    else if name == "color-picker"
                    then "${pkgs.hyprpicker}/bin/hyprpicker -a"
                    else if name == "resize-mode"
                    then "hyprctl dispatch submap resize"
                    else "true";
                })
                (filterBindings category.bindings))
            else buildCategorySubmenu category;
        })
      keybindDefs.categories
    );
  in {
    font = "${config.stylix.fonts.sansSerif.name} 14";
    background = "#${config.lib.stylix.colors.base00}";
    border = "#${config.lib.stylix.colors.base0D}";
    color = "#${config.lib.stylix.colors.base05}";
    anchor = "center";
    corner_r = 12;
    padding = 20;
    inherit menu;
  };
in {
  options.wm.which-key = {
    enable = lib.mkEnableOption "wlr-which-key keybind discovery";

    trigger = lib.mkOption {
      type = lib.types.str;
      default = "Shift+Slash";
      description = "Key combination to trigger which-key menu (typically Mod+?)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.wlr-which-key];

    # Generate YAML configs for enabled WMs
    xdg.configFile = lib.mkMerge [
      (lib.mkIf (config.wm.niri.enable or false) {
        "wlr-which-key/niri.yaml".text = lib.generators.toYAML {} (buildWhichKeyConfig "niri");
      })
      (lib.mkIf (config.wm.hyprland.enable or false) {
        "wlr-which-key/hyprland.yaml".text = lib.generators.toYAML {} (buildWhichKeyConfig "hyprland");
      })
    ];
  };
}
