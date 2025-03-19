{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    ssh-to-age # Convert ssh private keys in ed25519 format to age keys
    sops # Simple and flexible tool for managing secrets
  ];

  sops = {
    age.sshKeyPaths = ["/home/${inputs.self.lib.user}/.ssh/id_ed25519"];

    defaultSopsFile = "${inputs.self}/secrets/secrets.json";

    secrets = {
      "fesch/password" = {};
      "vpn/password" = {};
      "vpn/username" = {};
      "wifi/magenta-766410" = {};
      "wifi/hochbau-talstation" = {};
    };
  };
}
