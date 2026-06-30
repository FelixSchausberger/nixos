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
    SOPS_EDITOR = "nvim --clean";
  };

  # Use personal SSH key (same key material as .sops.yaml)
  sops = {
    age.sshKeyPaths = ["/home/schausberger/.ssh/id_ed25519"];
    defaultSopsFile = "${inputs.self}/secrets/secrets.yaml";
    defaultSopsFormat = "yaml";
  };
}
