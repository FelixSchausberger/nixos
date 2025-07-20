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

  sops = {
    age = {
      generateKey = false;
      keyFile = "/per/system/sops-key.txt";
      # sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };

    defaultSopsFile = "${inputs.self}/secrets/secrets.yaml";
    defaultSopsFormat = "yaml";
    # gnupg.sshKeyPaths = [];
  };
}
