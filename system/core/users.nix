{
  config,
  inputs,
  ...
}: {
  users.users = {
    "${inputs.self.lib.user}" = {
      isNormalUser = true;
      description = "Felix Schausberger";
      extraGroups = ["networkmanager" "video" "wheel"];
      password = config.sops.secrets."fesch/password".path;
      # openssh.authorizedKeys.keyFiles = [
      #   "${config.sops.secrets."fesch/id_ed25519".path}"
      # ];
    };
  };

  services.getty.autologinUser = inputs.self.lib.user;
}
