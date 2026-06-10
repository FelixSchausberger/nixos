{config, ...}: {
  # Work-specific Git configuration for PDTS Bitbucket repositories
  # This extends the base git configuration with work credentials

  programs.git = {
    includes = [
      {
        # Corporate Frequentis Git server configuration (SSH-based)
        condition = "hasconfig:remote.*.url:*git.frequentis.frq*";
        contents = {
          user = {
            name = "Felix Schausberger";
            email = "$(cat ${config.sops.secrets."work/email".path})";
          };
          # SSH is preferred, but keep HTTP config for fallback
          http = {
            sslVerify = false; # Disable SSL verification for corporate server
          };
        };
      }
    ];
  };

  # Work-related secrets for Corporate Git
  sops.secrets = {
    "work/email" = {
      mode = "0400";
    };
  };
}
