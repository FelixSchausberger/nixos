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

  # Set nvim as sops editor to avoid Helix terminal issues
  home.sessionVariables = {
    SOPS_EDITOR = "nvim";
  };

  # Minimal sops config - use same key as system
  sops = {
    age.keyFile = "/per/system/sops-key.txt";
    defaultSopsFile = "${inputs.self}/secrets/secrets.yaml";
    defaultSopsFormat = "yaml";
  };
}
