# Vitals system health monitor
# Runs a daemon that exposes a scored health API; the CLI queries it for
# ironbar widget output and interactive inspection.
{
  inputs,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  daemonPkg = inputs.vitals.packages.${system}.daemon;
  cliPkg = inputs.vitals.packages.${system}.cli;
in {
  home.packages = [cliPkg];

  # Daemon listens on 8080; align CLI default so `vitals status` works without --url
  home.sessionVariables.VITALS_URL = "http://127.0.0.1:8080";

  systemd.user.services.vitals-daemon = {
    Unit = {
      Description = "Vitals health monitoring daemon";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      Type = "simple";
      # Binary name reflects the upstream crate name; update when vitals renames its binaries
      ExecStart = "${daemonPkg}/bin/vitals-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
