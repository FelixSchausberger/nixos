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
    ssh-to-age # Derive age keys from SSH keys (needed for .envrc)
  ];

  # Set nvim as sops editor to avoid Helix terminal issues
  home.sessionVariables = {
    SOPS_EDITOR = "nvim";
  };

  # Minimal sops config - derive age key from SSH key
  sops = {
    # Use SSH key to derive age key automatically (same as .envrc)
    age.sshKeyPaths = [ "/per/home/schausberger/.ssh/id_ed25519" ];
    defaultSopsFile = "${inputs.self}/secrets/secrets.yaml";
    defaultSopsFormat = "yaml";
  };
}
