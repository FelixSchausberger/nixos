{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  home.packages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    sops # Simple and flexible tool for managing secrets
  ];

  # Minimal sops config - use same key as system
  sops = {
    age.keyFile = "/per/system/sops-key.txt";
    defaultSopsFile = "${inputs.self}/secrets/secrets_backup.yaml";
    defaultSopsFormat = "yaml";
  };
}
