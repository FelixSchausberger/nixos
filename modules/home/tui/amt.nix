{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    amtterm
  ];

  sops.secrets."amt/password" = {};
  # The AMT CA certificate (public) verifies the ME's TLS certificate. The ME
  # serves SOL only on the TLS port 16995; the unencrypted 16994 is closed, so
  # every SOL session runs over TLS.
  sops.secrets."amt/tls_ca_crt" = {};

  # Best practice: password travels via AMT_PASSWORD env only, never as -p
  # argv (visible in ps). amttool takes host first (amttool HOST info),
  # user is hardcoded to admin, auth comes from the environment.
  programs.fish.functions = {
    amtinfo = {
      description = "AMT info for m920q (reads password from sops)";
      body = ''
        if not test -f ${config.sops.secrets."amt/password".path}
            echo "AMT password not found at ${config.sops.secrets."amt/password".path}" >&2
            echo "Add it with: sops edit secrets/secrets.yaml  # amt.password" >&2
            return 1
        end
        env AMT_PASSWORD=(cat ${config.sops.secrets."amt/password".path}) \
          ${pkgs.amtterm}/bin/amttool 192.168.178.10 info $argv
      '';
    };
    amtterm-m920q = {
      description = "AMT SOL to m920q over TLS (reads password and CA from sops)";
      body = ''
        if not test -f ${config.sops.secrets."amt/password".path}
            echo "AMT password not found at ${config.sops.secrets."amt/password".path}" >&2
            return 1
        end
        if not test -f ${config.sops.secrets."amt/tls_ca_crt".path}
            echo "AMT CA certificate not found at ${config.sops.secrets."amt/tls_ca_crt".path}" >&2
            return 1
        end
        env AMT_PASSWORD=(cat ${config.sops.secrets."amt/password".path}) \
          ${pkgs.amtterm}/bin/amtterm -C ${config.sops.secrets."amt/tls_ca_crt".path} -u admin 192.168.178.10 $argv
      '';
    };
  };

  programs.bash.initExtra = lib.mkAfter ''
    amtinfo() {
      local pw_file="${config.sops.secrets."amt/password".path}"
      if [[ ! -f "$pw_file" ]]; then
        echo "AMT password not found at $pw_file" >&2
        echo "Add it with: sops edit secrets/secrets.yaml  # amt.password" >&2
        return 1
      fi
      AMT_PASSWORD="$(cat "$pw_file")" ${pkgs.amtterm}/bin/amttool 192.168.178.10 info "$@"
    }
    amtterm-m920q() {
      local pw_file="${config.sops.secrets."amt/password".path}"
      local ca_file="${config.sops.secrets."amt/tls_ca_crt".path}"
      if [[ ! -f "$pw_file" ]]; then
        echo "AMT password not found at $pw_file" >&2
        return 1
      fi
      if [[ ! -f "$ca_file" ]]; then
        echo "AMT CA certificate not found at $ca_file" >&2
        return 1
      fi
      AMT_PASSWORD="$(cat "$pw_file")" ${pkgs.amtterm}/bin/amtterm -C "$ca_file" -u admin 192.168.178.10 "$@"
    }
  '';
}
