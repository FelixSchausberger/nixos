{config, ...}: {
  users = {
    mutableUsers = false;
    users = {
      "fesch" = {
        isNormalUser = true;
        description = "Felix Schausberger";
        extraGroups = ["networkmanager" "input" "video" "wheel"];
        hashedPasswordFile = config.sops.secrets."fesch/password-hash".path; # Generate with `mkpasswd -m sha-512`
      };
    };
  };

  sops.secrets = {
    "fesch/password-hash" = {
      neededForUsers = true;
      mode = "0600";
      sopsFile = ../../secrets/secrets.json;
    };
  };
}
