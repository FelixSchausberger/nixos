{config, ...}: {
  users = {
    mutableUsers = false;
    users = {
      "schausberger" = {
        isNormalUser = true;
        description = "Felix Schausberger";
        extraGroups = ["networkmanager" "input" "video" "wheel"];
        hashedPasswordFile = config.sops.secrets."schausberger/password-hash".path; # Generate with `mkpasswd -m sha-512`
      };
      "rescue" = {
        isNormalUser = true;
        description = "Rescue account";
        extraGroups = ["networkmanager" "input" "video " "wheel"];
        hashedPassword = "$6$y5XRdWnsgrKZf0wi$EmBSwW3fIPrU090Ac2b1I4fUlk4nIXlflF6RtEYknhR94C.S6dttvG1O6dHUMt4NJDz7FCiChtfano6lXwr2.0";
      };
    };
  };

  sops.secrets = {
    "schausberger/password-hash" = {
      neededForUsers = true;
      mode = "0600";
    };
  };
}
