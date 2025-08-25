{
  lib,
  pkgs,
  ...
}: {
  # SOPS-nix configuration with age encryption
  environment.systemPackages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    ssh-to-age # Convert ssh private keys in ed25519 format to age keys
    sops # Simple and flexible tool for managing secrets
  ];

  # Per-host secrets structure
  sops = {
    age.keyFile = lib.mkForce "/per/system/sops-key.txt";

    # Default to shared secrets file, host-specific secrets are configured per-host
    defaultSopsFile = lib.mkDefault ../../../secrets/secrets.yaml;
  };
}
