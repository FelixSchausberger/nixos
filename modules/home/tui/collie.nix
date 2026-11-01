# Home side of the Collie phone bridge. The system module
# (modules/system/homelab/collie.nix) owns the service and the Tailscale
# Serve front door; this module renders the same option values into the
# user CLI's config so `collie pair`/`qr`/`doctor` resolve the identical
# instance (upstream's standalone layout: .env in ~/.config/collie).
# Values come from osConfig so the bridge, the CLI and the serve route
# cannot drift apart.
{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  cfg =
    (osConfig.modules.system.homelab or {
      }).collie
    or {
      enable = false;
      bridgePort = 8787;
      httpsPort = 8455;
      tailnetDomain = "";
      trustedUser = null;
    };
in {
  config = lib.mkIf cfg.enable {
    # Saved as the multiplexer choice the CLI verbs (pair, doctor, status)
    # read; the bridge gets its own mux pin from the service environment.
    home.sessionVariables.COLLIE_MUX = "herdr";

    home.packages = [pkgs.collie];

    # Must match the systemd collie service environment
    # (modules/system/homelab/collie.nix); identical values, single source
    # in the system options. Collie warns on start that it would prefer
    # mode 600, but a store-backed file is always 444-readonly; accepted
    # because nothing secret lives here - device pairing state is in
    # ~/.local/state/collie and the VAPID push keys that eventually become
    # sensitive must arrive through a sops template instead of this file.
    xdg.configFile."collie/.env".text =
      ''
        COLLIE_PORT=${toString cfg.bridgePort}
        COLLIE_HOST=127.0.0.1
        COLLIE_MUX=herdr
        COLLIE_SKIP_SERVE=1
        COLLIE_PUBLIC_HOSTS=${cfg.tailnetDomain},${cfg.tailnetDomain}:${toString cfg.httpsPort}
        COLLIE_ALLOWED_ORIGINS=https://${cfg.tailnetDomain}:${toString cfg.httpsPort}
        COLLIE_PUBLIC_URL=https://${cfg.tailnetDomain}:${toString cfg.httpsPort}
      ''
      + lib.optionalString (cfg.trustedUser != null) ''
        COLLIE_TRUSTED_USER=${cfg.trustedUser}
      ''
      + ''
        # Web Push is unconfigured: VAPID keys arrive through a sops template
        # once push is wanted (collie push-keys cannot write this read-only
        # file); until then the phone polls the dashboard only.
      '';
  };
}
