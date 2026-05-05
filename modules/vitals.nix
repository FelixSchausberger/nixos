{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.services.vitals;

  vitalsPackage = inputs.vitals.packages.${system};
in {
  options.services.vitals = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable vitals health monitoring daemon";
    };

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run on a headless server (use default.target instead of graphical-session.target)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.sessionVariables.VITALS_URL = "http://127.0.0.1:8080";

    systemd.user.services.vitals-daemon = {
      description = "Vitals health monitoring daemon";
      wantedBy = lib.mkIf cfg.headless ["default.target"];
      after = lib.mkIf cfg.headless ["default.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${vitalsPackage.daemon}/bin/vitals-daemon";
        Restart = "on-failure";
        RestartSec = 5;
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "vitals-daemon";
      };
    };
  };
}
