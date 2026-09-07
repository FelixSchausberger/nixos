# Wayle desktop shell integration for Wayland sessions.
# Wayle (Rust/GTK4) provides bar, notifications, OSD, wallpaper engine, and
# device controls. It has no launcher and no lock screen, so walker,
# cthulock, awww, and stasis from the custom stack stay active alongside it.
# Parameterized by session target so startup ordering matches the compositor.
# Upstream ships no flake; the package comes from nixpkgs (pkgs.wayle).
sessionTarget: {
  lib,
  config,
  pkgs,
  ...
}: let
  niri = config.wm.niri.enable or false;
  hyprland = config.wm.hyprland.enable or false;
  enabled = (config.wm.shell or "custom") == "wayle" && (niri || hyprland);
in {
  config = lib.mkIf enabled {
    home.packages = [pkgs.wayle];

    # Declarative starter config. Wayle hot-reloads on save; the settings
    # GUI writes runtime overrides to runtime.toml next to this file.
    # Full reference: https://wayle.app/config/
    xdg.configFile."wayle/config.toml".text = ''
      [bar]
      location = "top"

      [[bar.layout]]
      monitor = "*"
      left = ["dashboard"]
      center = ["clock"]
      right = ["volume", "network", "bluetooth", "battery"]

      [modules.clock]
      format = "%H:%M"

      [modules.weather]
      units = "metric"
    '';

    systemd.user.services.wayle = {
      Unit = {
        Description = "Wayle desktop shell (bar, notifications, OSD)";
        After = [sessionTarget];
        PartOf = [sessionTarget];
      };

      Service = {
        Type = "simple";
        # Install symbolic icons on every start; idempotent setup step
        # required once per the upstream install guide.
        ExecStartPre = "${pkgs.wayle}/bin/wayle icons setup";
        ExecStart = "${pkgs.wayle}/bin/wayle panel start";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [sessionTarget];
    };
  };
}
