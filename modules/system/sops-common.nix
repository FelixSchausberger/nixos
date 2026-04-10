# Common sops-nix configuration shared across all hosts
# Centralizes secrets definitions and templates to eliminate duplication
{
  config,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  # Configure sops-nix for secrets management
  sops = {
    # Default secrets file location
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Age key file location (from centralized defaults)
    age.keyFile = defaults.paths.sopsKeyFile;

    # Disable SSH key fallback - only use the age key file
    age.sshKeyPaths = [];
    gnupg.sshKeyPaths = [];

    # Common secrets used across all hosts
    secrets = {
      # API tokens
      "claude/default" = {};
      "github/token" = {
        owner = defaults.system.user;
      };
      "cachix/token" = {};

      # Cloud storage
      "rclone/client-secret" = {};
      "rclone/token" = {};

      # Bitwarden master password
      "bitwarden/master-password" = {};

      # Private user information
      "private/email" = {};
      "private/password-hash" = {
        neededForUsers = true;
      };
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

  # Ensure Nix uses the netrc file
  nix.settings.netrc-file = config.sops.templates."nix/netrc".path;

  # Create system mount directories for rclone
  systemd.tmpfiles.rules = [
    "d ${defaults.paths.mountDirs.base} 0755 root root -"
    "d ${defaults.paths.mountDirs.gdrive} 0755 root root -"
  ];
}
