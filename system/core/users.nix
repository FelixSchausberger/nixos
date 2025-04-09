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
        # hashedPassword = "$6$RzY5ZOXWbX5zyDOU$/L5gJrzpIEoNlGOlBClQw6ohC8P5rRt.oS7PFCOBLI1d6WJYqGMi53k8R9rN8pAvDRfsuVEvbXIRLBult5Qf.0"; # # Generate with `mkpasswd -m sha-512`
        hashedPasswordFile = config.sops.secrets."fesch/password-hash".path;
      };

      emergency = {
        isNormalUser = true;
        extraGroups = ["wheel" "networkmanager"];
        # hashedPassword = "$6$RzY5ZOXWbX5zyDOU$/L5gJrzpIEoNlGOlBClQw6ohC8P5rRt.oS7PFCOBLI1d6WJYqGMi53k8R9rN8pAvDRfsuVEvbXIRLBult5Qf.0"; # # Generate with `mkpasswd -m sha-512`
        hashedPassword = null; # No password login
        openssh.authorizedKeys.keyFiles = [
          config.sops.secrets."ssh/authorized_keys/emergency".path
        ];
      };
    };
  };

  sops.secrets = {
    "fesch/password" = {
      neededForUsers = true;
      mode = "0600";
      sopsFile = ../../secrets/secrets.json;
    };
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
