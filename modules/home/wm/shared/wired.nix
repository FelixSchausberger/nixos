# Shared Wired notification daemon integration for Wayland sessions.
# Binds service startup to the provided session target to avoid early-launch races.
# Active only for the "custom" shell: wayle and noctalia own notifications
# themselves, and two daemons on the notification bus means exactly one of
# them silently eats every toast.
sessionTarget: {
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkIf ((config.wm.shell or "custom") == "custom") {
    # Wired notification daemon configuration
    services.wired = {
      enable = lib.mkDefault true;
      config = ./wired.ron;
    };

    # Required packages for Wired
    home.packages = with pkgs; [
      libnotify # For notify-send command
    ];

    # Override systemd service to run in specified session
    systemd.user.services.wired = {
      Unit.After = lib.mkForce [sessionTarget];
      Install.WantedBy = lib.mkForce [sessionTarget];
    };
  };
}
