{
  config,
  pkgs,
  ...
}: {
  # Use sops templating to inject the email secret into rbw config
  # This avoids file conflicts by letting sops-nix handle the file creation
  sops.templates."rbw-config.json" = {
    content = builtins.toJSON {
      base_url = null;
      email = "${config.sops.placeholder."schausberger/email"}";
      identity_url = null;
      lock_timeout = 3600;
      pinentry = "${pkgs.pinentry-curses}/bin/pinentry";
    };
    path = "${config.home.homeDirectory}/.config/rbw/config.json";
    mode = "0600";
  };

  # Packages needed for rbw
  home.packages = with pkgs; [
    rbw # The rbw binary itself
    pinentry-curses # Pinentry for secure password input
  ];

  # Auto-unlock rbw service using stored master password
  # Disabled due to pinentry terminal issues in systemd service
  # systemd.user.services.rbw-unlock = {
  #   Unit = {
  #     Description = "Unlock Bitwarden vault (rbw)";
  #     After = ["graphical-session.target"];
  #     Wants = ["graphical-session.target"];
  #   };

  #   Service = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     ExecStart = let
  #       unlockScript = pkgs.writeShellScript "rbw-unlock" ''
  #         set -euo pipefail

  #         # Wait for master password secret to be available
  #         for i in {1..30}; do
  #           if [[ -f "${config.sops.secrets."bitwarden/master-password".path}" ]]; then
  #             break
  #           fi
  #           echo "Waiting for Bitwarden master password secret... ($i/30)"
  #           sleep 2
  #         done

  #         if [[ ! -f "${config.sops.secrets."bitwarden/master-password".path}" ]]; then
  #           echo "Error: Bitwarden master password secret not found"
  #           exit 1
  #         fi

  #         # Check if already unlocked
  #         if ${pkgs.rbw}/bin/rbw unlocked; then
  #           echo "rbw is already unlocked"
  #           exit 0
  #         fi

  #         # Unlock using stored master password (disable pinentry for automated unlock)
  #         export PINENTRY_USER_DATA="USE_CURSES=0"
  #         cat "${config.sops.secrets."bitwarden/master-password".path}" | ${pkgs.rbw}/bin/rbw unlock
  #         echo "rbw unlocked successfully"
  #       '';
  #     in
  #       toString unlockScript;
  #     Restart = "on-failure";
  #     RestartSec = "30s";
  #   };

  #   Install = {
  #     WantedBy = ["default.target"];
  #   };
  # };

  # Secrets for Bitwarden - stored in main secrets.yaml
  sops.secrets = {
    "bitwarden/master-password" = {
      mode = "0400";
    };
    "schausberger/email" = {
      mode = "0400";
    };
  };
}
