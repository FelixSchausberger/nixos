# VMware clipboard bridge for Wayland compositors
# Enables clipboard sync between Windows host and NixOS Wayland guest
# by running vmware-user with XWayland and bridging X11<->Wayland clipboards
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.wm.vmwareClipboard;

  # Bidirectional clipboard bridge script
  # Syncs X11 clipboard (used by vmware-user) with Wayland clipboard
  clipboardBridgeScript = pkgs.writeShellScript "vmware-clipboard-bridge" ''
    export DISPLAY=:0
    export XAUTHORITY=''${XDG_RUNTIME_DIR}/Xauthority

    last_x11=""
    last_wayland=""

    while true; do
      # Check X11 clipboard for changes (from VMware host)
      current_x11=$(${pkgs.xclip}/bin/xclip -selection clipboard -o 2>/dev/null || echo "")
      if [[ "$current_x11" != "$last_x11" && -n "$current_x11" ]]; then
        printf '%s' "$current_x11" | ${pkgs.wl-clipboard}/bin/wl-copy 2>/dev/null
        last_x11="$current_x11"
        last_wayland="$current_x11"
      fi

      # Check Wayland clipboard for changes (from guest apps)
      current_wayland=$(${pkgs.wl-clipboard}/bin/wl-paste 2>/dev/null || echo "")
      if [[ "$current_wayland" != "$last_wayland" && -n "$current_wayland" ]]; then
        printf '%s' "$current_wayland" | ${pkgs.xclip}/bin/xclip -selection clipboard 2>/dev/null
        last_wayland="$current_wayland"
        last_x11="$current_wayland"
      fi

      sleep 0.5
    done
  '';
in {
  options.wm.vmwareClipboard = {
    enable = lib.mkEnableOption "VMware clipboard bridge for Wayland";
  };

  config = lib.mkIf cfg.enable {
    # Required for X11 clipboard access
    home.packages = [pkgs.xclip];

    # VMware user agent service
    # Runs vmware-user-suid-wrapper connected to xwayland-satellite's X11 display
    systemd.user.services.vmware-user-wayland = {
      Unit = {
        Description = "VMware User Agent (Wayland)";
        After = ["graphical-session.target" "xwayland-satellite.service"];
        Wants = ["xwayland-satellite.service"]; # Soft dependency - start if available
        PartOf = ["graphical-session.target"];
        # Only start when graphical session is actually active
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Service = {
        # vmware-user daemonizes, so use forking type
        Type = "forking";
        Environment = [
          "DISPLAY=:0"
          "XAUTHORITY=%t/Xauthority"
        ];
        ExecStart = "/run/wrappers/bin/vmware-user-suid-wrapper";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };

    # Clipboard bridge service
    # Syncs X11 clipboard (vmware-user) with Wayland clipboard
    systemd.user.services.vmware-clipboard-bridge = {
      Unit = {
        Description = "VMware X11-Wayland Clipboard Bridge";
        After = ["graphical-session.target" "vmware-user-wayland.service"];
        Wants = ["vmware-user-wayland.service"];
        PartOf = ["graphical-session.target"];
        # Only start when graphical session is actually active
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Service = {
        Type = "simple";
        ExecStart = "${clipboardBridgeScript}";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
