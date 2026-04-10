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
      After = ["network-online.target"];
      Wants = ["network-online.target"];
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

    Install = {
      WantedBy = ["default.target"];
    };
  };
}
