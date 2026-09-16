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
      email = "${config.sops.placeholder."private/email"}";
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

  # Secrets for Bitwarden - stored in main secrets.yaml
  sops.secrets = {
    "bitwarden/master-password" = {
      mode = "0400";
    };
    "private/email" = {
      mode = "0400";
    };
  };
}
