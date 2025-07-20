{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.hyprland;

  # Music app selection for scratchpad
  musicPkg =
    if cfg.scratchpad.musicApp == "spotify-player"
    then pkgs.spotify-player
    else pkgs.spotify;

  musicCommand =
    if cfg.scratchpad.musicApp == "spotify-player"
    then "spotify_player"
    else "spotify";

  musicClass =
    if cfg.scratchpad.musicApp == "spotify-player"
    then "spotify_player"
    else "Spotify";

  # Notes app selection for scratchpad
  notesPkg =
    if cfg.scratchpad.notesApp == "basalt"
    then pkgs.basalt
    else pkgs.obsidian;

  notesCommand =
    if cfg.scratchpad.notesApp == "basalt"
    then "basalt"
    else "obsidian";

  notesClass =
    if cfg.scratchpad.notesApp == "basalt"
    then "basalt"
    else "obsidian";

  # Terminal selection for scratchpad
  terminalPkg =
    if cfg.terminal == "ghostty"
    then pkgs.ghostty
    else if cfg.terminal == "cosmic-term"
    then pkgs.cosmic-term
    else if cfg.terminal == "wezterm"
    then pkgs.wezterm
    else pkgs.ghostty; # Default to ghostty for better performance

  terminalCommand =
    if cfg.terminal == "ghostty"
    then "ghostty --class=scratchpad-terminal"
    else if cfg.terminal == "cosmic-term"
    then "cosmic-term --class=scratchpad-terminal"
    else if cfg.terminal == "wezterm"
    then "wezterm start --class=scratchpad-terminal"
    else "ghostty --class=scratchpad-terminal";
in {
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Scratchpad startup applications
      exec-once = [
        # Terminal scratchpad - using configured terminal with proper class
        "[workspace special:terminal silent] ${terminalPkg}/bin/${terminalCommand}"

        # Music scratchpad
        "[workspace special:music silent] ${musicPkg}/bin/${musicCommand}"

        # Planify scratchpad
        "[workspace special:planify silent] ${pkgs.planify}/bin/io.github.alainm23.planify"

        # Notes scratchpad
        "[workspace special:notes silent] ${notesPkg}/bin/${notesCommand}"
      ];

      # Enhanced window rules for scratchpads
      windowrulev2 = [
        # Terminal scratchpad - floating window in center
        "float,class:^(scratchpad-terminal)$"
        "size 80% 70%,class:^(scratchpad-terminal)$"
        "center,class:^(scratchpad-terminal)$"
        "opacity 0.95,class:^(scratchpad-terminal)$"
        "rounding 12,class:^(scratchpad-terminal)$"

        # Music scratchpad - floating window in center
        "float,class:^(${musicClass})$"
        "size 75% 65%,class:^(${musicClass})$"
        "center,class:^(${musicClass})$"
        "rounding 12,class:^(${musicClass})$"
        "opacity 0.98,class:^(${musicClass})$"

        # Planify scratchpad - floating window in center
        "float,class:^(io.github.alainm23.planify)$"
        "size 70% 60%,class:^(io.github.alainm23.planify)$"
        "center,class:^(io.github.alainm23.planify)$"
        "rounding 12,class:^(io.github.alainm23.planify)$"
        "opacity 0.98,class:^(io.github.alainm23.planify)$"

        # Notes scratchpad - floating window in center
        "float,class:^(${notesClass})$"
        "size 85% 75%,class:^(${notesClass})$"
        "center,class:^(${notesClass})$"
        "rounding 12,class:^(${notesClass})$"
        "opacity 0.98,class:^(${notesClass})$"

        # Generic scratchpad styling
        "float,class:^(scratchpad-.*)$"
        "center,class:^(scratchpad-.*)$"
        "rounding 12,class:^(scratchpad-.*)$"
        "stayfocused,class:^(scratchpad-.*)$"
      ];

      # Enhanced workspace rules for scratchpads
      workspace = [
        "special:terminal, gapsout:20, gapsin:10, bordersize:2, border:true, shadow:true"
        "special:music, gapsout:15, gapsin:8, bordersize:2, border:true, shadow:true"
        "special:planify, gapsout:20, gapsin:10, bordersize:2, border:true, shadow:true"
        "special:notes, gapsout:10, gapsin:5, bordersize:2, border:true, shadow:true"
      ];

      # Scratchpad-specific keybinds (defined in keybinds.nix but referenced here)
      bind = [
        # Quick scratchpad cycling
        "$mod CTRL, T, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace terminal || ${terminalPkg}/bin/${terminalCommand}"
        "$mod CTRL, S, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace music || ${musicPkg}/bin/${musicCommand}"
        "$mod CTRL, N, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace planify || ${pkgs.planify}/bin/io.github.alainm23.planify"
        "$mod CTRL, O, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace notes || ${notesPkg}/bin/${notesCommand}"
      ];
    };

    # Scratchpad utilities
    home.packages = [
      # Script to manage scratchpad applications
      (pkgs.writeShellScriptBin "hypr-scratchpad" ''
        #!/${pkgs.bash}/bin/bash

        # Scratchpad manager script
        case "$1" in
          "terminal"|"t")
            if ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl clients | grep -q "scratchpad-terminal"; then
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace terminal
            else
              ${terminalPkg}/bin/${terminalCommand} &
              sleep 0.5
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace terminal
            fi
            ;;
          "music"|"s")
            if ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl clients | grep -q "${musicClass}"; then
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace music
            else
              ${musicPkg}/bin/${musicCommand} &
              sleep 2
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace music
            fi
            ;;
          "planify"|"p"|"n")
            if ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl clients | grep -q "io.github.alainm23.planify"; then
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace planify
            else
              ${pkgs.planify}/bin/io.github.alainm23.planify &
              sleep 1
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace planify
            fi
            ;;
          "notes"|"o")
            if ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl clients | grep -q "${notesClass}"; then
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace notes
            else
              ${notesPkg}/bin/${notesCommand} &
              sleep 2
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglespecialworkspace notes
            fi
            ;;
          "list"|"l")
            echo "Available scratchpads:"
            echo "  terminal (t) - ${cfg.terminal}"
            echo "  music (s)    - ${cfg.scratchpad.musicApp}"
            echo "  planify (p|n) - Planify Task Manager"
            echo "  notes (o)    - ${cfg.scratchpad.notesApp}"
            ;;
          *)
            echo "Usage: hypr-scratchpad [terminal|music|planify|notes|list]"
            echo "   or: hypr-scratchpad [t|s|p|o|l]"
            ;;
        esac
      '')
    ];

    # Scratchpad-specific services
    systemd.user.services = {
      # Ensure scratchpad applications stay available
      scratchpad-keepalive = {
        Unit = {
          Description = "Keep scratchpad applications available";
          After = ["hyprland-session.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "scratchpad-keepalive" ''
            # Wait for Hyprland to be ready
            sleep 5

            # Pre-start scratchpad applications in background
            ${terminalPkg}/bin/${terminalCommand} &

            # Give them time to start
            sleep 2

            # Move to special workspaces
            ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch movetoworkspace special:terminal,class:scratchpad-terminal
          '';
          RemainAfterExit = true;
        };

        Install.WantedBy = ["hyprland-session.target"];
      };
    };
  };
}
