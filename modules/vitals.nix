{
  config,
  lib,
  ...
}: let
  cfg = config.services.vitals;
in {
  options.services.vitals = {
    enable = lib.mkEnableOption "vitals health monitoring daemon";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run on a headless server (use default.target instead of graphical-session.target)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.sessionVariables.VITALS_URL = "http://127.0.0.1:8080";
  };
}
