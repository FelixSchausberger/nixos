{config, ...}: {
  programs.awscli = {
    enable = true;
    settings."gcp" = {
      region = "eu-central-1"; # Frankfurt region
    };
    credentials."gcp" = {
      "aws_access_key_id" = "${config.sops.secrets."awscli/id".path}";
      "aws_secret_access_key" = "${config.sops.secrets."awscli/key".path}";
    };
  };
}
