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
    };

    defaultSopsFile = "${inputs.self}/secrets/secrets.json";
    gnupg.sshKeyPaths = [];
  };
}
