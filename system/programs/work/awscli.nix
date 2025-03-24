{config, ...}: {
  sops.secrets = {
    "awscli/id" = {};
    "awscli/key" = {};
  };

  # Write credentials directly to /root/.aws/credentials
  system.activationScripts.copyAwsCredentials = let
    accessKey = config.sops.secrets."awscli/id".path;
    secretKey = config.sops.secrets."awscli/key".path;
  in ''
    mkdir -p /root/.aws
    echo "[gcp]
    aws_access_key_id = $(cat ${accessKey})
    aws_secret_access_key = $(cat ${secretKey})" > /root/.aws/credentials
    chmod 600 /root/.aws/credentials
  '';
}
