{
  config,
  lib,
  pkgs,
  ...
}: {
  options.tui.bluetui = {
    enable = lib.mkEnableOption "bluetui Bluetooth manager" // {default = true;};
  };

  config = lib.mkIf config.tui.bluetui.enable {
    home.packages = with pkgs; [
      bluetui # Bluetooth TUI manager
    ];

    # Bluetui configuration
    xdg.configFile."bluetui/config.toml".text = ''
      # Bluetui configuration
      toggle_scanning = "s"

      [adapter]
      toggle_pairing = "p"
      toggle_power = "o"
      toggle_discovery = "d"

      [paired_device]
      unpair = "u"
      toggle_connect = " "
      toggle_trust = "t"
      rename = "e"

      [new_device]
      pair = "p"
    '';
  };
}
