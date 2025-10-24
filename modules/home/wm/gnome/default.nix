{pkgs, ...}: {
  home.packages = with pkgs; [
    dconf-editor # GSettings editor for GNOME
    gnome-tweaks # Tool to customize advanced GNOME 3 options
    wl-clipboard # Command-line copy/paste utilities for Wayland
  ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
      "org/gnome/desktop/wm/keybindings" = {
        # Window management
        close = ["<Super>q"];
        toggle-fullscreen = ["<Super>f"];
        toggle-maximized = ["<Super>space"];

        # Window focus (Colemak-DH N/E/I/O pattern)
        switch-to-workspace-left = ["<Super>n"];
        switch-to-workspace-right = ["<Super>o"];
        switch-to-workspace-up = ["<Super>i"];
        switch-to-workspace-down = ["<Super>e"];

        # Window movement
        move-to-workspace-left = ["<Super><Ctrl>n"];
        move-to-workspace-right = ["<Super><Ctrl>o"];
        move-to-workspace-up = ["<Super><Ctrl>i"];
        move-to-workspace-down = ["<Super><Ctrl>e"];

        # Monitor focus
        move-to-monitor-left = ["<Super><Shift>n"];
        move-to-monitor-right = ["<Super><Shift>o"];
        move-to-monitor-up = ["<Super><Shift>i"];
        move-to-monitor-down = ["<Super><Shift>e"];

        # Workspace navigation (U pattern)
        switch-to-workspace-1 = ["<Super>u"];
        switch-to-workspace-2 = ["<Super><Shift>u"];

        # Applications
        panel-main-menu = ["<Super>d"];
      };
      "org/gnome/shell" = {
        disable-user-extensions = false; # Enables user extensions
        enabled-extensions = with pkgs.gnomeExtensions; [
          caffeine.extensionUuid
          appindicator.extensionUuid
          blur-my-shell.extensionUuid
          clipboard-history.extensionUuid
          # gsconnect.extensionUuid
          pop-shell.extensionUuid
          vitals.extensionUuid
          compiz-windows-effect.extensionUuid
          transparent-window-moving.extensionUuid
        ];
      };

      # Blur My Shell configuration
      "org/gnome/shell/extensions/blur-my-shell" = {
        settings-version = 2;
      };

      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        brightness = 0.6;
        sigma = 30;
      };

      "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
        blur = true;
        brightness = 0.6;
        sigma = 30;
        static-blur = true;
        style-dash-to-dock = 0;
      };

      "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
        brightness = 0.6;
        sigma = 30;
      };

      "org/gnome/shell/extensions/blur-my-shell/window-list" = {
        brightness = 0.6;
        sigma = 30;
      };

      # Applications-specific blur settings for Zen and Ghostty
      "org/gnome/shell/extensions/blur-my-shell/applications" = {
        blur = true;
        brightness = 0.75; # Slightly brighter for better readability
        sigma = 25; # Moderate blur for applications
        enable-all = false; # Only blur specified applications
        whitelist = ["zen-alpha" "ghostty" "org.gnome.Nautilus"];
      };
    };
  };
}
