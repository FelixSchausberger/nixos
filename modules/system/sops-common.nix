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
    age.sshKeyPaths = ["/per/home/${defaults.system.user}/.ssh/id_ed25519"];
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
  # Managed garbage collection is disabled explicitly: the daemon knows only
  # `automatic` and `disabled` (no interval/schedule knob exists per
  # https://docs.determinate.systems/determinate-nix/determinate-nixd). Under
  # the default automatic strategy it woke the store every ~2 h overnight
  # (01:21, 02:18, 04:18, 06:18 on m920q, 2026-09-16) since it cannot be
  # confined to awake hours; freeing space is handled by the weekly daytime
  # nixos-cleanup (nix store gc), the build-time min-free/max-free pressure
  # checks, and the FilesystemWarn (20%) / FilesystemFull (10%) alerts.
  environment.etc."determinate/config.json" = lib.mkIf repoConfig.useDeterminateNix {
    text = builtins.toJSON {
      authentication.additionalNetrcSources = [
        config.sops.templates."nix/netrc".path
      ];
      garbageCollector.strategy = "disabled";
    };
    mode = "0644";
  };

  # The daemon orchestrator runs inside nix-daemon.service and reads
  # /etc/determinate/config.json at startup, so a strategy edit must
  # restart the unit on switch.
  systemd.services.nix-daemon.restartTriggers = [
    config.environment.etc."determinate/config.json".source
  ];

  # WiFi environment file for NM ensureProfiles (envsubst substitution)
  sops.templates."wifi/env" = {
    content = "WIFI_PSK=${config.sops.placeholder."wifi/pretty-fly-for-a-wifi"}";
    owner = defaults.system.user;
    path = "/run/secrets/wifi/env";
    mode = "0400";
  };

  # Create system mount directories for rclone
  systemd.tmpfiles.rules = [
    "d ${defaults.paths.mountDirs.base} 0755 root root -"
  ];
}
