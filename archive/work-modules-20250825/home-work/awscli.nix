{
  config,
  lib,
  ...
}: {
  programs.awscli = {
    enable = true;
  };

  sops.secrets = {
    "awscli/id" = {};
    "awscli/key" = {};
  };

  home.activation.setupAwsCredentials = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ~/.aws
    cat > ~/.aws/credentials << EOL
    [default]
    region = eu-central-1
    aws_access_key_id = $(cat ${config.sops.secrets."awscli/id".path})
    aws_secret_access_key = $(cat ${config.sops.secrets."awscli/key".path})

    [gcp]
    region = eu-central-1
    aws_access_key_id = $(cat ${config.sops.secrets."awscli/id".path})
    aws_secret_access_key = $(cat ${config.sops.secrets."awscli/key".path})
    EOL
    chmod 600 ~/.aws/credentials
  '';
}
