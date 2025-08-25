{pkgs, ...}: {
  # Note: hyprsunset doesn't have native home-manager options yet,
  # so we configure it as a systemd service
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprsunset Blue Light Filter";
      After = ["hyprland-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset -t 4500";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["hyprland-session.target"];
  };

  home.packages = [pkgs.hyprsunset];
}
