{inputs, ...}: {
  imports = ["${inputs.impermanence}/nixos.nix"];

  services.openssh.enable = true;

  environment.persistence."/per" = {
    users.${inputs.self.lib.user} = {
      directories = [
        {
          directory = ".ssh";
          mode = "0700";
        }
      ];
    };
  };
}
