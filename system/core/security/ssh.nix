{inputs, ...}: {
  imports = ["${inputs.impermanence}/nixos.nix"];

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
