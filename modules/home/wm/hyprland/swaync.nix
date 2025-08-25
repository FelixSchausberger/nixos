{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.wm.hyprland;
in {
  config = lib.mkIf cfg.enable {
    # SwayNotificationCenter configuration
    services.swaync = {
      enable = true;

      settings = {
        # Position and layer configuration
        positionX = "right";
        positionY = "top";
        layer = "overlay";
        control-center-layer = "top";
        layer-shell = true;
        cssPriority = "application";

        # Notification appearance
        notification-icon-size = 48;
        notification-body-image-height = 100;
        notification-body-image-width = 200;

        # Timeout settings
        timeout = 8;
        timeout-low = 4;
        timeout-critical = 0;

        # Behavior
        fit-to-screen = true;
        keyboard-shortcuts = true;
        image-visibility = "when-available";
        transition-time = 150;
        hide-on-clear = false;
        hide-on-action = true;

        # Features
        notification-2fa-action = true;
        notification-inline-replies = false;
        script-fail-notify = true;

        # Widget configuration
        widgets = [
          "inhibitors"
          "title"
          "dnd"
          "notifications"
        ];

        widget-config = {
          inhibitors = {
            text = "Inhibitors";
            button-text = "Clear All";
            clear-all-button = true;
          };
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = "Clear All";
          };
          dnd = {
            text = "Do Not Disturb";
          };
          notifications = {
            clear-all-button = true;
          };
        };
      };

      style = ''
        * {
          all: unset;
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
          color: #DBD3D3;
        }

        /* Notification Center */
        .floating-notifications {
          background: transparent;
        }

        /* Floating notification window with Spn4x-inspired styling */
        .floating-notifications .notification {
          backdrop-filter: blur(25px);
          -webkit-backdrop-filter: blur(25px);
          background: rgba(56, 58, 60, 0.9);
          border: 1px solid rgba(153, 147, 148, 0.5);
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
        }

        .notification-center {
          background: rgba(56, 58, 60, 0.85);
          border-radius: 12px;
          border: 1px solid rgba(153, 147, 148, 0.5);
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
          backdrop-filter: blur(15px);
          -webkit-backdrop-filter: blur(15px);
          margin: 8px;
          padding: 0;
        }

        .notification-center-header {
          background: transparent;
          padding: 12px 16px;
          border-bottom: 1px solid rgba(137, 180, 250, 0.3);
        }

        .notification-center-header .widget-title {
          font-size: 16px;
          font-weight: bold;
          color: #966166;
        }

        /* Individual Notifications */
        .notification {
          background: rgba(2, 20, 27, 0.5);
          border-radius: 8px;
          margin: 6px 8px;
          padding: 12px;
          border: 1px solid rgba(153, 147, 148, 0.5);
          backdrop-filter: blur(20px);
          -webkit-backdrop-filter: blur(20px);
          transition: all 0.15s ease-in-out;
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
        }

        .notification:hover {
          background: rgba(2, 20, 27, 0.7);
          border-color: rgba(150, 97, 102, 0.6);
          box-shadow: 0 6px 20px rgba(0, 0, 0, 0.4);
        }

        .notification.critical {
          border-color: rgba(231, 130, 132, 0.6);
          background: rgba(231, 130, 132, 0.1);
        }

        .notification-content {
          color: #cdd6f4;
        }

        .notification-content .summary {
          font-weight: bold;
          font-size: 14px;
          color: #966166;
        }

        .notification-content .body {
          color: #DBD3D3;
          margin-top: 4px;
          opacity: 0.9;
        }

        .notification-content .time {
          color: rgba(219, 211, 211, 0.6);
          font-size: 11px;
          margin-top: 4px;
        }

        /* Notification Actions */
        .notification-action {
          background: rgba(150, 97, 102, 0.2);
          border: 1px solid rgba(153, 147, 148, 0.5);
          border-radius: 6px;
          padding: 6px 12px;
          margin: 2px;
          color: #966166;
          font-size: 12px;
        }

        .notification-action:hover {
          background: rgba(150, 97, 102, 0.3);
        }

        /* Control Center */
        .control-center {
          background: rgba(30, 30, 46, 0.9);
          border-radius: 12px;
          border: 2px solid rgba(137, 180, 250, 0.6);
          margin: 8px;
          padding: 0;
          backdrop-filter: blur(15px);
        }

        .control-center-list {
          background: transparent;
        }

        .control-center-list-placeholder {
          color: #6c7086;
          font-style: italic;
          margin: 20px;
        }

        /* Widgets */
        .widget-title {
          color: #89b4fa;
          font-weight: bold;
          font-size: 14px;
          margin: 8px 12px;
        }

        .widget-dnd {
          background: rgba(137, 180, 250, 0.1);
          border-radius: 8px;
          margin: 8px;
          padding: 8px 12px;
        }

        .widget-dnd > switch {
          background: rgba(137, 180, 250, 0.2);
          border-radius: 12px;
        }

        .widget-dnd > switch:checked {
          background: rgba(137, 180, 250, 0.6);
        }

        .widget-dnd > switch slider {
          background: #89b4fa;
          border-radius: 10px;
        }

        /* Clear all button */
        .widget-title > button {
          background: rgba(137, 180, 250, 0.2);
          border: 1px solid rgba(137, 180, 250, 0.3);
          border-radius: 6px;
          padding: 4px 8px;
          color: #89b4fa;
          font-size: 11px;
          margin-left: auto;
        }

        .widget-title > button:hover {
          background: rgba(137, 180, 250, 0.3);
        }

        /* Inhibitors widget */
        .widget-inhibitors {
          background: rgba(243, 139, 168, 0.1);
          border-radius: 8px;
          margin: 8px;
          padding: 8px 12px;
          border: 1px solid rgba(243, 139, 168, 0.3);
        }

        .widget-inhibitors .widget-title {
          color: #f38ba8;
        }

        /* Scrollbar styling */
        scrollbar {
          background: transparent;
          width: 6px;
        }

        scrollbar slider {
          background: rgba(137, 180, 250, 0.4);
          border-radius: 3px;
          min-height: 20px;
        }

        scrollbar slider:hover {
          background: rgba(137, 180, 250, 0.6);
        }

        /* Animations */
        @keyframes slideIn {
          from {
            opacity: 0;
            transform: translateX(100%);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }

        .notification {
          animation: slideIn 0.2s ease-out;
        }
      '';
    };

    # Required packages for SwayNC
    home.packages = with pkgs; [
      swaynotificationcenter
      libnotify # For notify-send command
    ];

    # Override systemd service to only run in hyprland sessions
    systemd.user.services.swaync = {
      Unit.After = lib.mkForce ["hyprland-session.target"];
      Install.WantedBy = lib.mkForce ["hyprland-session.target"];
    };
  };
}
