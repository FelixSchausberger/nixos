{inputs, ...}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = "${inputs.self}/secrets/secrets.json";
    age.keyFile = "/per/system/sops-key.txt";
  };
}
