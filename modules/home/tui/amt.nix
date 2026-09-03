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

  programs.fish.functions = {
    amtinfo = {
      description = "AMT info for m920q (reads password from sops)";
      body = ''
        if not test -f ${config.sops.secrets."amt/password".path}
            echo "AMT password not found at ${config.sops.secrets."amt/password".path}" >&2
            echo "Add it with: sops edit secrets/secrets.yaml  # amt.password" >&2
            return 1
        end
        set -l pw (cat ${config.sops.secrets."amt/password".path})
        # amttool info is the canonical "amtinfo" — shows AMT version 12.x ok
        ${pkgs.amtterm}/bin/amttool info --host 192.168.178.10 --user admin --pass $pw $argv
      '';
    };
    amtterm-m920q = {
      description = "AMT SOL to m920q (reads password from sops)";
      body = ''
        if not test -f ${config.sops.secrets."amt/password".path}
            echo "AMT password not found at ${config.sops.secrets."amt/password".path}" >&2
            return 1
        end
        set -l pw (cat ${config.sops.secrets."amt/password".path})
        ${pkgs.amtterm}/bin/amtterm -u admin -p $pw 192.168.178.10 $argv
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
      ${pkgs.amtterm}/bin/amttool info --host 192.168.178.10 --user admin --pass "$(cat "$pw_file")" "$@"
    }
    amtterm-m920q() {
      local pw_file="${config.sops.secrets."amt/password".path}"
      if [[ ! -f "$pw_file" ]]; then
        echo "AMT password not found at $pw_file" >&2
        return 1
      fi
      ${pkgs.amtterm}/bin/amtterm -u admin -p "$(cat "$pw_file")" 192.168.178.10 "$@"
    }
  '';
}
