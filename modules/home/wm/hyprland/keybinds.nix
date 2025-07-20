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
          "$mod SHIFT, c, exec, ${pkgs.vscode}/bin/code"

          # Application launcher
          "$mod, D, exec, ${inputs.walker.packages.${pkgs.system}.default}/bin/walker"
          "$mod, R, exec, ${inputs.walker.packages.${pkgs.system}.default}/bin/walker --modules runner"
          "$mod SHIFT, D, exec, ${inputs.walker.packages.${pkgs.system}.default}/bin/walker --modules hyprland"

          # Window management
          "$mod, Space, togglefloating"
          "$mod, P, pseudo"
          "$mod, J, togglesplit"
          "$mod, F, fullscreen, 0" # Fullscreen
          "$mod SHIFT, F, fullscreen, 1" # Maximize
          "$mod, M, fullscreen, 2" # Fullscreen no bar

          # Window focusing (arrow keys + vim-like)
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"
          "$mod, h, movefocus, l"
          "$mod, l, movefocus, r"
          "$mod, k, movefocus, u"
          "$mod, j, movefocus, d"

          # Window movement (arrow keys + vim-like)
          "$mod SHIFT, left, movewindow, l"
          "$mod SHIFT, right, movewindow, r"
          "$mod SHIFT, up, movewindow, u"
          "$mod SHIFT, down, movewindow, d"
          "$mod SHIFT, h, movewindow, l"
          "$mod SHIFT, l, movewindow, r"
          "$mod SHIFT, k, movewindow, u"
          "$mod SHIFT, j, movewindow, d"

          # Window resizing (arrow keys + vim-like)
          "$mod ALT, left, resizeactive, -40 0"
          "$mod ALT, right, resizeactive, 40 0"
          "$mod ALT, up, resizeactive, 0 -40"
          "$mod ALT, down, resizeactive, 0 40"
          "$mod ALT, h, resizeactive, -40 0"
          "$mod ALT, l, resizeactive, 40 0"
          "$mod ALT, k, resizeactive, 0 -40"
          "$mod ALT, j, resizeactive, 0 40"

          # Workspace navigation (enhanced)
          "$mod CTRL, right, workspace, e+1"
          "$mod CTRL, left, workspace, e-1"
          "$mod CTRL, l, workspace, e+1"
          "$mod CTRL, h, workspace, e-1"
          "$mod, Prior, workspace, e-1" # Page Up
          "$mod, Next, workspace, e+1" # Page Down
          "$mod, Tab, workspace, previous"
          "$mod SHIFT, Tab, workspace, previous"

          # Workspace movement
          "$mod CTRL SHIFT, right, movetoworkspace, e+1"
          "$mod CTRL SHIFT, left, movetoworkspace, e-1"
          "$mod CTRL SHIFT, l, movetoworkspace, e+1"
          "$mod CTRL SHIFT, h, movetoworkspace, e-1"
          "$mod SHIFT, Prior, movetoworkspace, e-1"
          "$mod SHIFT, Next, movetoworkspace, e+1"

          # Scratchpads (Super + letter for application name)
          "$mod, T, togglespecialworkspace, terminal"
          "$mod SHIFT, T, movetoworkspace, special:terminal"
          "$mod, S, togglespecialworkspace, spotify"
          "$mod SHIFT, S, movetoworkspace, special:spotify"
          "$mod, N, togglespecialworkspace, planify"
          "$mod SHIFT, N, movetoworkspace, special:planify"
          "$mod, O, togglespecialworkspace, obsidian"
          "$mod SHIFT, O, movetoworkspace, special:obsidian"

          # Screenshots (enhanced)
          ", Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy && ${pkgs.libnotify}/bin/notify-send 'Screenshot' 'Area copied to clipboard'"
          "$mod, Print, exec, ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy && ${pkgs.libnotify}/bin/notify-send 'Screenshot' 'Screen copied to clipboard'"
          "SHIFT, Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png && ${pkgs.libnotify}/bin/notify-send 'Screenshot' 'Saved to Pictures/Screenshots'"
          "$mod SHIFT, Print, exec, ${pkgs.grim}/bin/grim ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png && ${pkgs.libnotify}/bin/notify-send 'Screenshot' 'Saved to Pictures/Screenshots'"

          # Screen recording
          "$mod, R, exec, ${pkgs.wf-recorder}/bin/wf-recorder -g \"$(${pkgs.slurp}/bin/slurp)\" -f ${config.home.homeDirectory}/Videos/Recordings/$(date +'%Y-%m-%d_%H-%M-%S').mp4"
          "$mod SHIFT, R, exec, ${pkgs.killall}/bin/killall wf-recorder && ${pkgs.libnotify}/bin/notify-send 'Recording stopped'"

          # Utilities
          "$mod, V, exec, ${inputs.walker.packages.${pkgs.system}.default}/bin/walker --modules clipboard"
          "$mod, period, exec, ${inputs.walker.packages.${pkgs.system}.default}/bin/walker --modules emoji" # Emoji picker
          "$mod ALT, B, exec, ${inputs.bluetui.packages.${pkgs.system}.default}/bin/bluetui" # Bluetooth management

          # Color picker
          "$mod SHIFT, C, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a && ${pkgs.libnotify}/bin/notify-send 'Color picked' 'Copied to clipboard'"

          # Audio controls (additional)
          "$mod, equal, exec, ${pkgs.avizo}/bin/volumectl -u up"
          "$mod, minus, exec, ${pkgs.avizo}/bin/volumectl -u down"
          "$mod, 0, exec, ${pkgs.avizo}/bin/volumectl toggle-mute"

          # Brightness controls (additional)
          "$mod SHIFT, equal, exec, ${pkgs.avizo}/bin/lightctl up"
          "$mod SHIFT, minus, exec, ${pkgs.avizo}/bin/lightctl down"

          # Window grouping
          "$mod, G, togglegroup"
          "$mod SHIFT, G, lockactivegroup, toggle"
          "$mod ALT, left, changegroupactive, b"
          "$mod ALT, right, changegroupactive, f"
          "$mod ALT, h, changegroupactive, b"
          "$mod ALT, l, changegroupactive, f"

          # Special actions
          "$mod, I, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch toggleopaque"
          "$mod SHIFT, I, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch pin"
          # "$mod CTRL, I, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch togglechromakey" # Toggle ChromaKey transparency - disabled due to plugin build issues
          "$mod, U, pseudo"
          "$mod SHIFT, U, togglesplit"

          # Layout switching
          "$mod CTRL, Space, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch layoutmsg orientationcycle"
          "$mod ALT, Space, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl dispatch layoutmsg swapwithmaster"

          # Notification controls (SwayNotificationCenter)
          "$mod, Escape, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client -t -sw" # Toggle notification center
          "$mod SHIFT, Escape, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client -C" # Close all notifications
          "$mod CTRL, Escape, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client -R" # Reload config
          "$mod ALT, Escape, exec, ${pkgs.swaynotificationcenter}/bin/swaync-client -d -sw" # Toggle DND mode

          # System controls
          "$mod CTRL, R, exec, ${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl reload"
          "$mod CTRL, Q, exec, ${pkgs.systemd}/bin/systemctl --user restart hyprland"

          # Quick applications
          "$mod ALT, T, exec, ${pkgs.btop}/bin/btop"
          "$mod ALT, F, exec, ${cfg.fileManager}"
          "$mod ALT, W, exec, ${cfg.browser} --new-window"
          "$mod ALT, C, exec, ${pkgs.gnome-calculator}/bin/gnome-calculator"

          # Resize mode
          "$mod, B, submap, resize" # B for reSize (avoiding R for recording)
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
        ", XF86Bluetooth, exec, ${inputs.bluetui.packages.${pkgs.system}.default}/bin/bluetui"
        ", XF86Tools, exec, ${pkgs.gnome-control-center}/bin/gnome-control-center"
        ", XF86Search, exec, ${inputs.walker.packages.${pkgs.system}.default}/bin/walker"
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
        "CAPS, Caps_Lock, exec, ${pkgs.libnotify}/bin/notify-send 'Caps Lock' 'is remapped to Escape'"
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

      # Vim keys
      binde = , l, resizeactive, 40 0
      binde = , h, resizeactive, -40 0
      binde = , k, resizeactive, 0 -40
      binde = , j, resizeactive, 0 40

      # Fine adjustment (Shift for smaller steps)
      binde = SHIFT, right, resizeactive, 10 0
      binde = SHIFT, left, resizeactive, -10 0
      binde = SHIFT, up, resizeactive, 0 -10
      binde = SHIFT, down, resizeactive, 0 10
      binde = SHIFT, l, resizeactive, 10 0
      binde = SHIFT, h, resizeactive, -10 0
      binde = SHIFT, k, resizeactive, 0 -10
      binde = SHIFT, j, resizeactive, 0 10

      # Big adjustment (Alt for larger steps)
      binde = ALT, right, resizeactive, 100 0
      binde = ALT, left, resizeactive, -100 0
      binde = ALT, up, resizeactive, 0 -100
      binde = ALT, down, resizeactive, 0 100
      binde = ALT, l, resizeactive, 100 0
      binde = ALT, h, resizeactive, -100 0
      binde = ALT, k, resizeactive, 0 -100
      binde = ALT, j, resizeactive, 0 100

      # Presets
      bind = , 1, resizeactive, exact 25% 25%
      bind = , 2, resizeactive, exact 50% 50%
      bind = , 3, resizeactive, exact 75% 75%
      bind = , 4, resizeactive, exact 100% 100%

      # Exit resize mode
      bind = , escape, submap, reset
      bind = , Return, submap, reset
      bind = $mod, B, submap, reset

      submap = reset
    '';

    # Create required directories
    home.file = {
      "${config.home.homeDirectory}/Pictures/Screenshots/.keep".text = "";
      "${config.home.homeDirectory}/Videos/Recordings/.keep".text = "";
    };
  };
}
