sessionTarget: {pkgs, ...}: {
  config = {
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
            Environment = ["WAYLAND_DISPLAY=wayland-0"];
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
