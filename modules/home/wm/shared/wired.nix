sessionTarget: {
  lib,
  pkgs,
  ...
}: {
  config = {
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
