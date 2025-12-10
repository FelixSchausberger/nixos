{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wm.hyprland;
  safeNotifySend = import ../../../../home/lib/safe-notify-send.nix {inherit pkgs config lib;};
  safeNotifyBin = "${safeNotifySend}/bin/safe-notify-send";
in {
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      # Key bindings with improved shortcuts
      bind =
        [
          # System controls
          "$mod, Return, exec, $terminal"
          "$mod, Q, killactive"
          "$mod SHIFT, E, exit"
          "$mod, L, exec, loginctl lock-session"

          # Application shortcuts
          "$mod, w, exec, $browser"
          "$mod, e, exec, $fileManager"
          "$mod, c, exec, ${pkgs.helix}/bin/hx"

          # Application launcher
          "$mod, D, exec, ${inputs.walker.packages.${pkgs.hostPlatform.system}.default}/bin/walker"
          # "$mod, R, exec, ${inputs.walker.packages.${pkgs.hostPlatform.system}.default}/bin/walker --modules runner"
          # "$mod SHIFT, D, exec, ${inputs.walker.packages.${pkgs.hostPlatform.system}.default}/bin/walker --modules hyprland"

          # Window management
          "$mod, Space, togglefloating"
          "$mod, P, pseudo"
          "$mod, J, togglesplit"
          "$mod, F, fullscreen, 0" # Fullscreen
          "$mod SHIFT, F, fullscreen, 1" # Maximize
          "$mod, M, fullscreen, 2" # Fullscreen no bar

          # Window focusing (arrow keys + Colemak-DH N/E/I/O)
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"
          "$mod, n, movefocus, l"
          "$mod, o, movefocus, r"
          "$mod, i, movefocus, u"
          "$mod, e, movefocus, d"

          # Window movement (arrow keys + Colemak-DH N/E/I/O)
          "$mod CTRL, left, movewindow, l"
          "$mod CTRL, right, movewindow, r"
          "$mod CTRL, up, movewindow, u"
          "$mod CTRL, down, movewindow, d"
          "$mod CTRL, n, movewindow, l"
          "$mod CTRL, o, movewindow, r"
          "$mod CTRL, i, movewindow, u"
          "$mod CTRL, e, movewindow, d"

          # Window resizing (arrow keys + Colemak-DH N/E/I/O)
          "$mod ALT, left, resizeactive, -40 0"
          "$mod ALT, right, resizeactive, 40 0"
          "$mod ALT, up, resizeactive, 0 -40"
          "$mod ALT, down, resizeactive, 0 40"
          "$mod ALT, n, resizeactive, -40 0"
          "$mod ALT, o, resizeactive, 40 0"
          "$mod ALT, i, resizeactive, 0 -40"
          "$mod ALT, e, resizeactive, 0 40"

          # Workspace navigation (U/I pattern + Page keys)
          "$mod, u, workspace, e-1"
          "$mod, Prior, workspace, e-1" # Page Up
          "$mod SHIFT, u, workspace, e+1"
          "$mod, Next, workspace, e+1" # Page Down
          "$mod, Tab, workspace, previous"
          "$mod SHIFT, Tab, workspace, previous"

          # Workspace movement
          "$mod CTRL, u, movetoworkspace, e-1"
          "$mod CTRL, Prior, movetoworkspace, e-1"
          "$mod CTRL SHIFT, u, movetoworkspace, e+1"
          "$mod CTRL, Next, movetoworkspace, e+1"

          # Scratchpads using pyprland
          "$mod, T, exec, ${pkgs.pyprland}/bin/pypr toggle terminal"
          "$mod, S, exec, ${pkgs.pyprland}/bin/pypr toggle music"
          "$mod, N, exec, ${pkgs.pyprland}/bin/pypr toggle planify"
          "$mod, O, exec, ${pkgs.pyprland}/bin/pypr toggle notes"
          "$mod, B, exec, ${pkgs.pyprland}/bin/pypr toggle bluetui"
          "$mod, U, exec, ${pkgs.pyprland}/bin/pypr toggle impala" # Impala WiFi Manager
          "$mod, Y, exec, ${pkgs.pyprland}/bin/pypr toggle teams" # MS Teams (work-specific)

          # Pyprland Quality of Life Features
          "$mod, slash, exec, ${pkgs.pyprland}/bin/pypr menu" # Show shortcuts menu
          "$mod SHIFT, slash, exec, scratchpad list" # Show scratchpad help
          "$mod CTRL, K, exec, ${pkgs.pyprland}/bin/pypr change_workspace +1" # Next workspace (follow focus)
          "$mod CTRL, J, exec, ${pkgs.pyprland}/bin/pypr change_workspace -1" # Prev workspace (follow focus)

          # Monitor Management
          "$mod SHIFT, Left, exec, ${pkgs.pyprland}/bin/pypr shift_monitors -1" # Shift workspaces left
          "$mod SHIFT, Right, exec, ${pkgs.pyprland}/bin/pypr shift_monitors +1" # Shift workspaces right
          "$mod ALT, D, exec, ${pkgs.pyprland}/bin/pypr toggle_dpms" # Toggle displays (DPMS)

          # Screenshots
          ", Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy && ${safeNotifyBin} 'Screenshot' 'Area copied to clipboard'"
          "$mod, Print, exec, ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy && ${safeNotifyBin} 'Screenshot' 'Screen copied to clipboard'"
          "SHIFT, Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png && ${safeNotifyBin} 'Screenshot' 'Saved to Pictures/Screenshots'"
          "$mod SHIFT, Print, exec, ${pkgs.grim}/bin/grim ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png && ${safeNotifyBin} 'Screenshot' 'Saved to Pictures/Screenshots'"
          # Utilities
          "$mod, V, exec, ${inputs.walker.packages.${pkgs.hostPlatform.system}.default}/bin/walker --modules clipboard"
          "$mod, period, exec, ${inputs.walker.packages.${pkgs.hostPlatform.system}.default}/bin/walker --modules emoji" # Emoji picker

          # Color picker
          "$mod SHIFT, C, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a && ${safeNotifyBin} 'Color picked' 'Copied to clipboard'"

          # Audio controls
          # "$mod, equal, exec, ${pkgs.avizo}/bin/volumectl -u up"
          # "$mod, minus, exec, ${pkgs.avizo}/bin/volumectl -u down"
          # "$mod, 0, exec, ${pkgs.avizo}/bin/volumectl toggle-mute"

          # Brightness controls
          # "$mod SHIFT, equal, exec, ${pkgs.avizo}/bin/lightctl up"
          # "$mod SHIFT, minus, exec, ${pkgs.avizo}/bin/lightctl down"

          # Window management extras
          "$mod, c, centerwindow"
          "$mod, r, exec, ${inputs.hyprland.packages.${pkgs.hostPlatform.system}.hyprland}/bin/hyprctl dispatch cyclenext"
          "$mod SHIFT, r, exec, ${inputs.hyprland.packages.${pkgs.hostPlatform.system}.hyprland}/bin/hyprctl dispatch cycleprev"
          "$mod, comma, exec, ${inputs.hyprland.packages.${pkgs.hostPlatform.system}.hyprland}/bin/hyprctl dispatch togglesplit"
          "$mod, period, exec, ${inputs.hyprland.packages.${pkgs.hostPlatform.system}.hyprland}/bin/hyprctl dispatch pseudo"

          # Monitor focus (Shift + N/E/I/O)
          "$mod SHIFT, left, focusmonitor, l"
          "$mod SHIFT, right, focusmonitor, r"
          "$mod SHIFT, up, focusmonitor, u"
          "$mod SHIFT, down, focusmonitor, d"
          "$mod SHIFT, n, focusmonitor, l"
          "$mod SHIFT, o, focusmonitor, r"
          "$mod SHIFT, i, focusmonitor, u"
          "$mod SHIFT, e, focusmonitor, d"

          # Move to monitor (Ctrl+Shift + N/E/I/O)
          "$mod CTRL SHIFT, left, movewindow, mon:l"
          "$mod CTRL SHIFT, right, movewindow, mon:r"
          "$mod CTRL SHIFT, up, movewindow, mon:u"
          "$mod CTRL SHIFT, down, movewindow, mon:d"
          "$mod CTRL SHIFT, n, movewindow, mon:l"
          "$mod CTRL SHIFT, o, movewindow, mon:r"
          "$mod CTRL SHIFT, i, movewindow, mon:u"
          "$mod CTRL SHIFT, e, movewindow, mon:d"

          # Window grouping
          "$mod, G, togglegroup"
          "$mod SHIFT, G, lockactivegroup, toggle"

          # Special actions
          "$mod SHIFT, P, pseudo"

          # Layout switching
          "$mod CTRL, Space, exec, ${inputs.hyprland.packages.${pkgs.hostPlatform.system}.hyprland}/bin/hyprctl dispatch layoutmsg orientationcycle"
          "$mod ALT, Space, exec, ${inputs.hyprland.packages.${pkgs.hostPlatform.system}.hyprland}/bin/hyprctl dispatch layoutmsg swapwithmaster"

          # Notification controls (Wired)
          "$mod, Escape, exec, ${safeNotifyBin} 'Test' 'Wired notification system'" # Test notification
          "$mod SHIFT, Escape, exec, pkill -SIGUSR1 wired" # Close all notifications
          "$mod CTRL, Escape, exec, systemctl --user restart wired" # Restart wired

          # System controls
          "$mod CTRL, R, exec, ${inputs.hyprland.packages.${pkgs.hostPlatform.system}.hyprland}/bin/hyprctl reload && ${safeNotifyBin} 'Hyprland' 'Configuration reloaded'"
          "$mod CTRL, Q, exec, ${pkgs.systemd}/bin/systemctl --user restart hyprland"

          # Resize mode
          "$mod, R, submap, resize"
        ]
        ++ (
          # Workspace bindings 1-10
          builtins.concatLists (builtins.genList (x: let
              ws = let c = (x + 1) / 10; in builtins.toString (x + 1 - (c * 10));
            in [
              "$mod, ${ws}, workspace, ${toString (x + 1)}"
              "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
              "$mod ALT, ${ws}, movetoworkspacesilent, ${toString (x + 1)}"
            ])
            10)
        );

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
        "$mod ALT, mouse:272, resizewindow"
      ];

      # Volume and brightness controls (smooth)
      bindle = [
        ", XF86AudioRaiseVolume, exec, ${pkgs.avizo}/bin/volumectl -u up"
        ", XF86AudioLowerVolume, exec, ${pkgs.avizo}/bin/volumectl -u down"
        ", XF86MonBrightnessUp, exec, ${pkgs.avizo}/bin/lightctl up"
        ", XF86MonBrightnessDown, exec, ${pkgs.avizo}/bin/lightctl down"

        # Mouse wheel workspace switching (when holding Super)
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      # Media controls and special keys
      bindl = [
        ", XF86AudioMute, exec, ${pkgs.avizo}/bin/volumectl toggle-mute"
        ", XF86AudioMicMute, exec, ${pkgs.avizo}/bin/volumectl -m toggle-mute"
        ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ", XF86AudioPause, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
        ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"
        ", XF86AudioStop, exec, ${pkgs.playerctl}/bin/playerctl stop"

        # Laptop special keys
        ", XF86Display, exec, ${pkgs.wdisplays}/bin/wdisplays"
        ", XF86WLAN, exec, ${pkgs.networkmanagerapplet}/bin/nm-connection-editor"
        ", XF86Bluetooth, exec, hypr-scratchpad bluetui"
        ", XF86Tools, exec, ${pkgs.gnome-control-center}/bin/gnome-control-center"
        ", XF86Search, exec, ${inputs.walker.packages.${pkgs.hostPlatform.system}.default}/bin/walker"
        ", XF86LaunchA, exec, ${cfg.fileManager}"
        ", XF86Explorer, exec, ${cfg.fileManager}"

        # Power management
        ", XF86PowerOff, exec, ${pkgs.systemd}/bin/systemctl suspend"
        ", XF86Sleep, exec, ${pkgs.systemd}/bin/systemctl suspend"
        ", XF86Suspend, exec, ${pkgs.systemd}/bin/systemctl suspend"
      ];

      # Global keybinds (work even when apps have focus)
      bindel = [
        # Global media controls
        ", XF86AudioRaiseVolume, exec, ${pkgs.avizo}/bin/volumectl -u up"
        ", XF86AudioLowerVolume, exec, ${pkgs.avizo}/bin/volumectl -u down"
      ];

      # Lid switch and power button
      bindr = [
        "CAPS, Caps_Lock, exec, ${safeNotifyBin} 'Caps Lock' 'is remapped to Escape'"
      ];
    };

    # Enhanced resize submap with more options
    wayland.windowManager.hyprland.extraConfig = ''
      # Resize submap
      submap = resize
      # Arrow keys
      binde = , right, resizeactive, 40 0
      binde = , left, resizeactive, -40 0
      binde = , up, resizeactive, 0 -40
      binde = , down, resizeactive, 0 40

      # Colemak-DH N/E/I/O keys
      binde = , o, resizeactive, 40 0
      binde = , n, resizeactive, -40 0
      binde = , i, resizeactive, 0 -40
      binde = , e, resizeactive, 0 40

      # Fine adjustment (Shift for smaller steps)
      binde = SHIFT, right, resizeactive, 10 0
      binde = SHIFT, left, resizeactive, -10 0
      binde = SHIFT, up, resizeactive, 0 -10
      binde = SHIFT, down, resizeactive, 0 10
      binde = SHIFT, o, resizeactive, 10 0
      binde = SHIFT, n, resizeactive, -10 0
      binde = SHIFT, i, resizeactive, 0 -10
      binde = SHIFT, e, resizeactive, 0 10

      # Big adjustment (Alt for larger steps)
      binde = ALT, right, resizeactive, 100 0
      binde = ALT, left, resizeactive, -100 0
      binde = ALT, up, resizeactive, 0 -100
      binde = ALT, down, resizeactive, 0 100
      binde = ALT, o, resizeactive, 100 0
      binde = ALT, n, resizeactive, -100 0
      binde = ALT, i, resizeactive, 0 -100
      binde = ALT, e, resizeactive, 0 100

      # Presets
      bind = , 1, resizeactive, exact 25% 25%
      bind = , 2, resizeactive, exact 50% 50%
      bind = , 3, resizeactive, exact 75% 75%
      bind = , 4, resizeactive, exact 100% 100%

      # Exit resize mode
      bind = , escape, submap, reset
      bind = , Return, submap, reset
      bind = $mod, R, submap, reset

      submap = reset
    '';
  };
}
