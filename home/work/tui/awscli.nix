{config, ...}: {
  programs.awscli = {
    enable = true;
    settings = {
      default = {
        region = "eu-central-1";
      };
      gcp = {
        region = "eu-central-1";
      };
    };
    credentials = {
      default = {
        aws_access_key_id = config.sops.secrets."awscli/id".path;
        aws_secret_access_key = config.sops.secrets."awscli/key".path;
      };
      gcp = {
        aws_access_key_id = config.sops.secrets."awscli/id".path;
        aws_secret_access_key = config.sops.secrets."awscli/key".path;
      };
    };
  };

  sops.secrets = {
    "awscli/id" = {};
    "awscli/key" = {};
  };
}
