{
  config,
  pkgs,
  ...
}: {
  programs.rbw = {
    enable = true;
    settings = {
      email = "fel.schausberger@gmail.com";
      pinentry = pkgs.pinentry-curses;
      lock_timeout = 3600;
    };
  };

  # Packages needed for rbw
  home.packages = with pkgs; [
    pinentry-curses
  ];

  # Auto-unlock rbw service using stored master password
  systemd.user.services.rbw-unlock = {
    Unit = {
      Description = "Unlock Bitwarden vault (rbw)";
      After = ["graphical-session.target"];
      Wants = ["graphical-session.target"];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        unlockScript = pkgs.writeShellScript "rbw-unlock" ''
          set -euo pipefail

          # Wait for master password secret to be available
          for i in {1..30}; do
            if [[ -f "${config.sops.secrets."bitwarden/master-password".path}" ]]; then
              break
            fi
            echo "Waiting for Bitwarden master password secret... ($i/30)"
            sleep 2
          done

          if [[ ! -f "${config.sops.secrets."bitwarden/master-password".path}" ]]; then
            echo "Error: Bitwarden master password secret not found"
            exit 1
          fi

          # Check if already unlocked
          if ${pkgs.rbw}/bin/rbw unlocked; then
            echo "rbw is already unlocked"
            exit 0
          fi

          # Unlock using stored master password
          cat "${config.sops.secrets."bitwarden/master-password".path}" | ${pkgs.rbw}/bin/rbw unlock
          echo "rbw unlocked successfully"
        '';
      in
        toString unlockScript;
      Restart = "on-failure";
      RestartSec = "30s";
    };

    Install = {
      WantedBy = ["default.target"];
    };
  };

  # Secret for Bitwarden master password - stored in main secrets.yaml
  sops.secrets = {
    "bitwarden/master-password" = {
      mode = "0400";
    };
  };
}
