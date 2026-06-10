# Common sops-nix configuration shared across all hosts
{
  config,
  inputs,
  lib,
  repoConfig,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = defaults.paths.sopsKeyFile;
    age.sshKeyPaths = [];
    gnupg.sshKeyPaths = [];

    secrets = {
      "claude/default" = {};
      "github/token" = {
        owner = defaults.system.user;
      };
      "cachix/token" = {};

      "rclone/client-secret" = {
        owner = defaults.system.user;
      };
      "rclone/token" = {
        owner = defaults.system.user;
      };

      "bitwarden/master-password" = {};

      "private/email" = {};
      "private/password-hash" = {
        neededForUsers = true;
      };

      "wifi/pretty-fly-for-a-wifi" = {};
    };

    # Create netrc file for nix GitHub and Cachix access
    templates."nix/netrc" = {
      content = ''
        machine github.com
        login token
        password ${config.sops.placeholder."github/token"}

        machine api.github.com
        login token
        password ${config.sops.placeholder."github/token"}

        machine cachix.cachix.org
        login token
        password ${config.sops.placeholder."cachix/token"}
      '';
      owner = defaults.system.user;
      path = "/etc/nix/netrc";
      mode = "0440";
    };
  };

  # Standard Nix reads credentials directly from /etc/nix/netrc.
  nix.settings = lib.mkIf (!repoConfig.useDeterminateNix) {
    netrc-file = config.sops.templates."nix/netrc".path;
  };

  # Determinate Nixd owns nix.settings.netrc-file and expects /nix/var/determinate/netrc.
  # Merge our sops-managed credentials into Determinate's effective netrc.
  environment.etc."determinate/config.json" = lib.mkIf repoConfig.useDeterminateNix {
    text = builtins.toJSON {
      authentication.additionalNetrcSources = [
        config.sops.templates."nix/netrc".path
      ];
    };
    mode = "0644";
  };

  # WiFi environment file for NM ensureProfiles (envsubst substitution)
  sops.templates."wifi/env" = {
    content = "WIFI_PSK=${config.sops.placeholder."wifi/pretty-fly-for-a-wifi"}";
    owner = defaults.system.user;
    path = "/run/secrets/wifi/env";
    mode = "0400";
  };

  # iwd network config for systemd-networkd-based WiFi (e.g., m920q specialisation)
  sops.templates."wifi/iwd" = {
    content = ''
      [Security]
      Passphrase=${config.sops.placeholder."wifi/pretty-fly-for-a-wifi"}

      [Settings]
      AutoConnect=true
    '';
    owner = "root";
    group = "root";
    mode = "0600";
  };

  # Create system mount directories for rclone
  systemd.tmpfiles.rules = [
    "d ${defaults.paths.mountDirs.base} 0755 root root -"
  ];
}
