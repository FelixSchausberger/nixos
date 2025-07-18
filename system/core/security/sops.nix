{
  inputs,
  pkgs,
  ...
}: {
  # TEMPORARILY DISABLED - SOPS SYSTEM CAUSING BUILD FAILURES
  # imports = [
  #   inputs.sops-nix.nixosModules.sops
  # ];

  environment.systemPackages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    ssh-to-age # Convert ssh private keys in ed25519 format to age keys
    sops # Simple and flexible tool for managing secrets
  ];

  # TEMPORARILY DISABLED - SOPS CONFIGURATION CAUSING BUILD FAILURES
  # sops = {
  #   defaultSopsFile = "${inputs.self}/secrets/secrets.json";
  #   age.keyFile = "/per/system/sops-key.txt";
  #   # age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  # };
}
