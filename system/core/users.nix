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
        hashedPasswordFile = config.sops.secrets."fesch/password-hash".path;
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
