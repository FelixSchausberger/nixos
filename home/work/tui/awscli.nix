{
  config,
  pkgs,
  ...
}: {
  programs.awscli = {
    enable = true;
    settings = {
      default = {
        region = "eu-central-1";
        aws_access_key_id_file = config.sops.secrets."awscli/id".path;
        aws_secret_access_key_file = config.sops.secrets."awscli/key".path;
      };
      gcp = {
        region = "eu-central-1";
        aws_access_key_id_file = config.sops.secrets."awscli/id".path;
        aws_secret_access_key_file = config.sops.secrets."awscli/key".path;
      };
    };
  };

  sops.secrets = {
    "awscli/id" = {};
    "awscli/key" = {};
  };

  # Add home-manager activation hook
  home.activation.awsCredentials = let
    credsFile = "${config.home.homeDirectory}/.aws/credentials";
  in ''
    mkdir -p ${config.home.homeDirectory}/.aws
    echo "[default]
    aws_access_key_id = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."awscli/id".path})
    aws_secret_access_key = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."awscli/key".path})

    [gcp]
    aws_access_key_id = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."awscli/id".path})
    aws_secret_access_key = $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."awscli/key".path})" > ${credsFile}
    chmod 600 ${credsFile}
  '';
}
