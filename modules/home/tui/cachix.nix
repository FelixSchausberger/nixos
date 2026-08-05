{
  config,
  pkgs,
  ...
}: {
  # Redefine at home-manager level to get a user-readable secret path
  # The key already exists in secrets.yaml (used by sops-common.nix for netrc)
  sops.secrets."cachix/token" = {};

  home.packages = [pkgs.cachix];

  systemd.user.services.cachix-watch-store = {
    Unit = {
      Description = "Cachix watch-store daemon for automatic binary cache population";
      # Wait for sops-nix to decrypt the cachix auth token before starting
      After = ["network-online.target" "sops-nix.service"];
      Wants = ["network-online.target"];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 10;
    };

    Service = {
      Type = "simple";
      # Read raw token into CACHIX_AUTH_TOKEN at startup; exec replaces the shell
      # so systemd tracks the correct PID
      ExecStart = let
        script = pkgs.writeShellScript "cachix-watch-store" ''
          export CACHIX_AUTH_TOKEN=$(< ${config.sops.secrets."cachix/token".path})
          exec ${pkgs.cachix}/bin/cachix watch-store felixschausberger
        '';
      in "${script}";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    # Not enabled at login; the timer below runs the daemon only during the
    # off-hours window so build uploads never saturate the link during work hours.
    Install = {
      WantedBy = [];
    };
  };

  # Pushing build outputs saturates the upload (34 Mbit/s measured vs the
  # 23 Mbit/s plan cap) and causes bufferbloat for the whole household.
  # Run the daemon only between 02:00 and 06:00.
  systemd.user.timers.cachix-watch-store = {
    Unit = {
      Description = "Start cachix watch-store during the off-hours window";
    };
    # No Persistent: a missed window (machine off at 02:00) must NOT trigger a
    # catch-up push during work hours — that would defeat the off-hours goal.
    Timer = {
      OnCalendar = "*-*-* 02:00:00";
    };
    Install.WantedBy = ["timers.target"];
  };

  systemd.user.services.cachix-watch-stop = {
    Unit = {
      Description = "Stop cachix watch-store at the end of the off-hours window";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user stop cachix-watch-store.service";
    };
  };

  systemd.user.timers.cachix-watch-stop = {
    Unit = {
      Description = "Stop cachix watch-store daily at 06:00";
    };
    Timer = {
      OnCalendar = "*-*-* 06:00:00";
    };
    Install.WantedBy = ["timers.target"];
  };
}
