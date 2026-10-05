{
  config,
  pkgs,
  ...
}: {
  # Use sops templating to inject the email secret into rbw config
  # This avoids file conflicts by letting sops-nix handle the file creation
  sops.templates."rbw-config.json" = {
    content = builtins.toJSON {
      # Self-hosted vaultwarden on m920q, reached over the tailnet via its
      # Tailscale Serve port (modules/system/homelab/vaultwarden.nix — keep
      # the port in sync with its httpsPort default). identity_url and
      # notifications_url derive from base_url; null would mean the hosted
      # Bitwarden API. The fleet-wide literal mirrors how ntfy's base-url
      # names m920q directly.
      base_url = "https://m920q.tailf2f0ca.ts.net:8447";
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
    "private/email" = {
      mode = "0400";
    };
  };
}
