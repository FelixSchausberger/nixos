{
  config,
  inputs,
  ...
}: {
  imports = ["${inputs.impermanence}/nixos.nix"];

  services.openssh.enable = true;

  sops.secrets = {
    "ssh/authorized_keys/regular" = {};
    "ssh/authorized_keys/magazino" = {};
  };

  environment = {
    etc = {
      "ssh/ssh_host_ed25519_key.pub" = {
        source = config.sops.secrets."ssh/authorized_keys/regular".path;
      };
      "ssh/ssh_host_ed25519_magazino_pki.pub" = {
        source = config.sops.secrets."ssh/authorized_keys/magazino".path;
      };
    };

    persistence."/per" = {
      users.${inputs.self.lib.user} = {
        directories = [
          {
            directory = ".ssh";
            mode = "0700";
          }
        ];
      };
    };
  };
}
