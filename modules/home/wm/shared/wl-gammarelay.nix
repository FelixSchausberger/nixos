# Shared wl-gammarelay service wiring for color-temperature automation in Wayland sessions.
# Uses session-target ordering so gamma control starts only after compositor availability.
# Disabled for noctalia and dms, which provide their own night-light
# service (DMS via its night IPC target).
sessionTarget: {
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkIf (!(builtins.elem (config.wm.shell or "custom") ["noctalia" "dms"])) {
    # Provide package
    home.packages = with pkgs; [wl-gammarelay-rs];

    # Systemd service definitions
    systemd = {
      user.services = {
        wl-gammarelay = {
          Unit = {
            Description = "Adjust gamma/temperature/brightness under Wayland";
            After = [sessionTarget];
          };

          Service = {
            Type = "simple";
            ExecStart = "${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs run";
            Restart = "on-failure";
            RestartSec = 1;
            # WAYLAND_DISPLAY comes from the systemd activation environment
            # (UWSM exports it before the session target is reached); pinning
            # it to wayland-0 breaks whenever the compositor allocates
            # another socket.
          };

          Install.WantedBy = [sessionTarget];
        };

        wl-gammarelay-temperature = {
          Unit = {
            Description = "Set temperature using wl-gammarelay";
            After = ["wl-gammarelay.service"];
            Requires = ["wl-gammarelay.service"];
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs set-temperature 4500'";
            RemainAfterExit = true;
          };

          Install.WantedBy = [sessionTarget];
        };
      };
    };
  };
}
