# Shared lock-screen integration for Wayland sessions using waylock.
# Parameterized by session target so systemd ordering matches the active compositor.
# Kept for the custom and wayle shells (wayle ships no lock screen).
# Noctalia and dms lock via their own lockscreen services.
# Waylock renders a solid color and authenticates through PAM (no config
# file); the PAM service lives in system/core/security.
_sessionTarget: {
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkIf (!(builtins.elem (config.wm.shell or "custom") ["noctalia" "dms"])) {
    home.packages = [pkgs.waylock];
  };
}
