{inputs, ...}: {
  # imports = [
  #   inputs.sops-nix.homeManagerModules.sops
  # ];

  sops = {
    age.sshKeyPaths = ["/home/${inputs.self.lib.user}/.ssh/id_ed25519"];
    defaultSopsFile = "${inputs.self}/secrets/secrets.json";
  };
}
