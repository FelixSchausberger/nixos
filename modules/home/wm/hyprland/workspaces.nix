{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Enhanced workspace configuration
      workspace = [
        # Main workspaces with persistent and default settings
        "1, persistent:true, default:true, gapsout:20, gapsin:10" # Empty workspace
        "2, persistent:true, defaultName:Browser, gapsout:15, gapsin:8"
        "3, persistent:true, defaultName:Development, gapsout:12, gapsin:6"
        "4, persistent:true, defaultName:Files, gapsout:15, gapsin:8"
        "5, persistent:true, defaultName:Media, gapsout:10, gapsin:5"
        "6, persistent:true, defaultName:Communication, gapsout:15, gapsin:8"
        "7, persistent:true, defaultName:Gaming, gapsout:5, gapsin:2"
        "8, persistent:true, defaultName:System, gapsout:15, gapsin:8"
        "9, persistent:true, defaultName:Misc, gapsout:15, gapsin:8"
        "10, persistent:true, defaultName:Temp, gapsout:15, gapsin:8"
      ];

      # Advanced window rules for workspace assignment
      windowrulev2 = [
        # Browser applications (Workspace 2)
        "workspace 2,class:^(zen-alpha)$"
        "workspace 2,class:^(zen)$"
        "workspace 2,class:^(firefox)$"
        "workspace 2,class:^(chromium-browser)$"
        "workspace 2,class:^(Google-chrome)$"
        "workspace 2,class:^(brave-browser)$"
        "workspace 2,class:^(microsoft-edge)$"

        # Development applications (Workspace 3)
        "workspace 3,class:^(code-url-handler)$"
        "workspace 3,class:^(Code)$"
        "workspace 3,class:^(codium-url-handler)$"
        "workspace 3,class:^(VSCodium)$"
        "workspace 3,class:^(jetbrains-.*)$"
        "workspace 3,class:^(Godot)$"
        "workspace 3,class:^(godot)$"
        "workspace 3,class:^(Unity)$"
        "workspace 3,class:^(Blender)$"
        "workspace 3,class:^(org.gnome.TextEditor)$"
        "workspace 3,class:^(nvim)$"
        "workspace 3,class:^(helix)$"

        # File managers (Workspace 4)
        "workspace 4,class:^(cosmic-files)$"
        "workspace 4,class:^(org.gnome.Nautilus)$"
        "workspace 4,class:^(Thunar)$"
        "workspace 4,class:^(spacedrive)$"
        "workspace 4,class:^(pcmanfm)$"
        "workspace 4,class:^(nemo)$"
        "workspace 4,class:^(dolphin)$"

        # Media applications (Workspace 5)
        "workspace 5,class:^(mpv)$"
        "workspace 5,class:^(vlc)$"
        "workspace 5,class:^(org.gnome.Totem)$"
        "workspace 5,class:^(celluloid)$"
        "workspace 5,class:^(gimp-2.10)$"
        "workspace 5,class:^(krita)$"
        "workspace 5,class:^(inkscape)$"
        "workspace 5,class:^(darktable)$"
        "workspace 5,class:^(rawtherapee)$"
        "workspace 5,class:^(audacity)$"
        "workspace 5,class:^(ardour)$"
        "workspace 5,class:^(kdenlive)$"
        "workspace 5,class:^(shotcut)$"
        "workspace 5,class:^(obs)$"

        # Communication (Workspace 6)
        "workspace 6,class:^(discord)$"
        "workspace 6,class:^(Discord)$"
        "workspace 6,class:^(WebCord)$"
        "workspace 6,class:^(Element)$"
        "workspace 6,class:^(telegram-desktop)$"
        "workspace 6,class:^(Signal)$"
        "workspace 6,class:^(slack)$"
        "workspace 6,class:^(teams-for-linux)$"
        "workspace 6,class:^(zoom)$"
        "workspace 6,class:^(Skype)$"
        "workspace 6,class:^(org.gnome.Evolution)$"
        "workspace 6,class:^(thunderbird)$"

        # Gaming (Workspace 7) - only if gaming module is loaded
        "workspace 7,class:^(steam)$"
        "workspace 7,class:^(Steam)$"
        "workspace 7,class:^(lutris)$"
        "workspace 7,class:^(Lutris)$"
        "workspace 7,class:^(heroic)$"
        "workspace 7,class:^(bottles)$"
        "workspace 7,class:^(org.prismlauncher.PrismLauncher)$"
        "workspace 7,class:^(Minecraft)$"
        "workspace 7,class:^(steam_app_).*"
        "workspace 7,class:^(gamescope)$"

        # System applications (Workspace 8)
        "workspace 8,class:^(org.gnome.Settings)$"
        "workspace 8,class:^(gnome-control-center)$"
        "workspace 8,class:^(pavucontrol)$"
        "workspace 8,class:^(org.gnome.SystemMonitor)$"
        "workspace 8,class:^(btop)$"
        "workspace 8,class:^(htop)$"
        "workspace 8,class:^(org.gnome.DiskUtility)$"
        "workspace 8,class:^(GParted)$"
        "workspace 8,class:^(baobab)$"
        "workspace 8,class:^(org.gnome.Characters)$"
        "workspace 8,class:^(org.gnome.Calculator)$"
        "workspace 8,class:^(org.gnome.Weather)$"
        "workspace 8,class:^(org.gnome.clocks)$"

        # Misc applications (Workspace 9)
        "workspace 9,class:^(libreoffice-.*)$"
        "workspace 9,class:^(org.gnome.TextEditor)$"
        "workspace 9,class:^(simple-scan)$"
        "workspace 9,class:^(evince)$"
        "workspace 9,class:^(org.gnome.Evince)$"
        "workspace 9,class:^(zathura)$"
        "workspace 9,class:^(sioyek)$"
        "workspace 9,class:^(calibre)$"
        "workspace 9,class:^(foliate)$"

        # Ensure workspace 1 stays empty by redirecting new windows
        "workspace 2,class:^.*$,workspace:1"

        # Exception for specific utilities that should stay on workspace 1
        "workspace 1,class:^(floating-mode)$"
        "workspace 1,class:^(it.mijorus.smile)$"
        "workspace 1,class:^(org.gnome.Calculator)$"
        "workspace 1,floating:1"

        # Pin important floating windows
        "pin,class:^(floating-mode)$"
        "pin,class:^(it.mijorus.smile)$"
        "pin,title:^(Picture-in-Picture)$"

        # Workspace-specific styling
        "opacity 0.95,workspace:2" # Slightly transparent browsers
        "opacity 1.0,workspace:3" # Opaque development
        "opacity 0.98,workspace:5" # Media applications
        "opacity 1.0,workspace:7" # Games need full opacity
      ];

      # Dynamic workspace behavior
      bind = [
        # Smart workspace switching with fallback
        "$mod, 1, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch workspace 1 || ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch workspace empty"

        # Workspace-specific actions
        "$mod ALT, 2, exec, ${cfg.browser}"
        "$mod ALT, 3, exec, ${pkgs.vscode}/bin/code"
        "$mod ALT, 4, exec, ${cfg.fileManager}"
        "$mod ALT, 5, exec, ${pkgs.spotify}/bin/spotify"
        "$mod ALT, 6, exec, ${pkgs.discord}/bin/discord"
        "$mod ALT, 8, exec, ${pkgs.gnome-control-center}/bin/gnome-control-center"

        # Workspace overview and management
        # "$mod, grave, hyprexpo:expo, toggle" # Hyprexpo plugin (temporarily disabled)
        "$mod CTRL, A, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch focusworkspaceoncurrentmonitor 1"

        # Move window to workspace and follow
        "$mod CTRL SHIFT, 1, movetoworkspace, 1; workspace, 1"
        "$mod CTRL SHIFT, 2, movetoworkspace, 2; workspace, 2"
        "$mod CTRL SHIFT, 3, movetoworkspace, 3; workspace, 3"
        "$mod CTRL SHIFT, 4, movetoworkspace, 4; workspace, 4"
        "$mod CTRL SHIFT, 5, movetoworkspace, 5; workspace, 5"
        "$mod CTRL SHIFT, 6, movetoworkspace, 6; workspace, 6"
        "$mod CTRL SHIFT, 7, movetoworkspace, 7; workspace, 7"
        "$mod CTRL SHIFT, 8, movetoworkspace, 8; workspace, 8"
        "$mod CTRL SHIFT, 9, movetoworkspace, 9; workspace, 9"
        "$mod CTRL SHIFT, 0, movetoworkspace, 10; workspace, 10"
      ];
    };

    # Workspace management utilities
    home.packages = [
      # Workspace manager script
      (pkgs.writeShellScriptBin "hypr-workspace" ''
        #!/${pkgs.bash}/bin/bash

        # Workspace management script
        case "$1" in
          "list"|"l")
            echo "Workspace Layout:"
            echo "  1: Empty (clean slate)"
            echo "  2: Browser (${cfg.browser})"
            echo "  3: Development (VS Code, IDEs)"
            echo "  4: Files (${cfg.fileManager})"
            echo "  5: Media (Spotify, GIMP, Videos)"
            echo "  6: Communication (Discord, Slack)"
            echo "  7: Gaming (Steam, Lutris)"
            echo "  8: System (Settings, Monitors)"
            echo "  9: Misc (Documents, Reading)"
            echo " 10: Temp (Temporary work)"
            ;;
          "empty"|"clean")
            # Clean all workspaces except 1
            for i in {2..10}; do
              ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch closewindow workspace:$i 2>/dev/null || true
            done
            ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch workspace 1
            echo "All workspaces cleaned, moved to workspace 1"
            ;;
          "restore"|"r")
            # Restore default workspace applications
            ${cfg.browser} &
            ${pkgs.vscode}/bin/code &
            ${cfg.fileManager} &
            sleep 2
            ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch workspace 1
            echo "Default applications restored"
            ;;
          "move")
            if [ -z "$2" ] || [ -z "$3" ]; then
              echo "Usage: hypr-workspace move <from> <to>"
              exit 1
            fi
            # Move all windows from one workspace to another
            ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch movetoworkspace "$3",workspace:"$2"
            echo "Moved all windows from workspace $2 to workspace $3"
            ;;
          "name")
            if [ -z "$2" ] || [ -z "$3" ]; then
              echo "Usage: hypr-workspace name <workspace> <name>"
              exit 1
            fi
            # Rename workspace (if supported by bar)
            ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch renameworkspace "$2" "$3"
            echo "Renamed workspace $2 to '$3'"
            ;;
          *)
            echo "Usage: hypr-workspace [list|empty|restore|move|name]"
            echo "  list (l)     - Show workspace layout"
            echo "  empty        - Clean all workspaces except 1"
            echo "  restore (r)  - Restore default applications"
            echo "  move <f> <t> - Move windows between workspaces"
            echo "  name <w> <n> - Rename workspace"
            ;;
        esac
      '')
    ];
  };
}
