{
  config,
  inputs,
  ...
}: {
  users = {
    mutableUsers = false;
    users = {
      "${inputs.self.lib.user}" = {
        isNormalUser = true;
        description = "Felix Schausberger";
        extraGroups = ["networkmanager" "video" "wheel"];
        hashedPasswordFile = config.sops.secrets."fesch/password-hash".path; # Generate with `mkpasswd -m sha-512`
      };

      emergency = {
        isNormalUser = true;
        extraGroups = ["wheel" "networkmanager"];
        hashedPassword = null; # No password login
        openssh.authorizedKeys.keyFiles = [
          config.sops.secrets."ssh/authorized_keys/emergency".path
        ];
      };
    };
  };

  sops.secrets = {
    "fesch/password-hash" = {
      neededForUsers = true;
      mode = "0600";
      sopsFile = ../../secrets/secrets.json;
    };
    "ssh/authorized_keys/emergency" = {
      mode = "0400";
      sopsFile = ../../secrets/secrets.json;
    };
  };
}
