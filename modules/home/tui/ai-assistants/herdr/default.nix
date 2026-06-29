{
  config,
  lib,
  pkgs,
  ...
}: {
  options.tui.herdr = {
    enable =
      lib.mkEnableOption "herdr terminal multiplexer for AI agents"
      // {
        default = true;
      };
  };

  config = lib.mkIf config.tui.herdr.enable {
    home.packages = [pkgs.herdr];
  };
}
