# System-side option for the vitals health monitoring daemon.
# The daemon/CLI wiring lives in the home-manager module
# (modules/home/tui/vitals.nix), which reads services.vitals.headless from
# osConfig to pick the session target.
{lib, ...}: {
  options.services.vitals = {
    enable = lib.mkEnableOption "vitals health monitoring daemon";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run on a headless server (use default.target instead of graphical-session.target)";
    };
  };
}
