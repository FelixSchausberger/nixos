{
  config,
  pkgs,
  ...
}: {
  sops.secrets = {
    "awscli/id" = {};
    "awscli/key" = {};
  };

  # Write credentials directly to /root/.aws/credentials
  system.activationScripts.copyAwsCredentials = {
    deps = ["setupSecrets"]; # Add this dependency
    text = let
      accessKey = config.sops.secrets."awscli/id".path;
      secretKey = config.sops.secrets."awscli/key".path;
    in ''
            mkdir -p /root/.aws
            # Check if files exist and are not empty
            if [ -s "${accessKey}" ] && [ -s "${secretKey}" ]; then
              echo "[gcp]
      aws_access_key_id = $(${pkgs.coreutils}/bin/cat ${accessKey})
      aws_secret_access_key = $(${pkgs.coreutils}/bin/cat ${secretKey})" > /root/.aws/credentials
              chmod 600 /root/.aws/credentials
            else
              echo "Warning: AWS credential secrets not available or empty" >&2
            fi
    '';
  };
}
