{
  lib,
  pkgs,
  config,
  ...
}: {
  # Sopswarden handles sops configuration, but we still need the tools
  environment.systemPackages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    ssh-to-age # Convert ssh private keys in ed25519 format to age keys
    sops # Simple and flexible tool for managing secrets
  ];

  # Per-host secrets structure while maintaining sopswarden compatibility
  sops = {
    age.keyFile = lib.mkForce "/per/system/sops-key.txt";

    # Default to host-specific secrets file if it exists, otherwise use global
    defaultSopsFile = lib.mkDefault (
      let
        hostSecretsFile = ../../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
      in
        if builtins.pathExists hostSecretsFile
        then hostSecretsFile
        else ../../../secrets/secrets.yaml
    );
  };
}
