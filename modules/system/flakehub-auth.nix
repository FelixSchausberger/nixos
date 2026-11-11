# FlakeHub credential handling for Determinate Nix.
#
# determinate-nixd merges every configured netrc source into
# /nix/var/determinate/netrc and writes that file 0644 root:root. Merging the
# sops template (the GitHub PAT and Cachix token, kept at 0440 on purpose)
# therefore republishes those secrets to every local account. The file has to
# stay readable by the interactive user, whose nix client authenticates GitHub
# and FlakeHub fetches itself, so its mode is narrowed to 0640
# root:<user group> instead of 0600. The daemon rewrites the file on login and
# on restart, so a path unit reapplies the mode after every rewrite.
#
# The expiry metric exists because a FlakeHub static token cannot renew itself:
# determinate-nixd has no refresh verb and the OIDC login methods target CI
# identities, not a workstation. A silent expiry turns every flake operation
# into a 401 - source fetches from api.flakehub.com are otherwise public - so
# the token's JWT exp claim is exported to the node exporter textfile
# collector and FlakehubTokenExpiringSoon alerts on it. The token is decoded
# in-process and never copied anywhere.
{
  config,
  inputs,
  lib,
  pkgs,
  repoConfig,
  ...
}: let
  inherit (inputs.self.lib) defaults;
  user = defaults.system.user;
  group = config.users.users.${user}.group;
  netrc = "/nix/var/determinate/netrc";
  metricsDir = "/var/lib/node-exporter/textfile";

  expiryMetric = pkgs.writeShellApplication {
    name = "flakehub-token-expiry";
    runtimeInputs = with pkgs; [coreutils gawk gnugrep jq];
    text = ''
      set -euo pipefail
      metric="${metricsDir}/flakehub-token.prom"

      # Hosts without the textfile collector, and hosts where nobody has
      # logged in yet, publish no series so the alert stays quiet.
      if [[ ! -d "${metricsDir}" || ! -r "${netrc}" ]]; then
        rm -f "$metric"
        exit 0
      fi

      token="$(awk '$1 == "machine" && $2 == "flakehub.com" { print $NF; exit }' "${netrc}")"
      token="''${token#flakehub1_}"

      # The JWT payload is the middle dot-separated segment, base64url encoded
      # without padding.
      payload="''${token#*.}"
      payload="''${payload%%.*}"
      case $((''${#payload} % 4)) in
        2) payload="''${payload}==" ;;
        3) payload="''${payload}=" ;;
      esac
      exp="$(
        printf '%s' "$payload" \
          | tr '_-' '/+' \
          | base64 -d 2>/dev/null \
          | jq -r '.exp // empty' 2>/dev/null || true
      )"

      if [[ -z "$exp" ]]; then
        rm -f "$metric"
        exit 0
      fi

      tmp="$(mktemp "${metricsDir}/.flakehub-token.XXXXXX")"
      {
        echo "# HELP nix_flakehub_token_expiry_timestamp_seconds Unix time at which the FlakeHub token expires"
        echo "# TYPE nix_flakehub_token_expiry_timestamp_seconds gauge"
        echo "nix_flakehub_token_expiry_timestamp_seconds $exp"
      } > "$tmp"
      chmod 644 "$tmp"
      mv "$tmp" "$metric"
    '';
  };
in
  lib.mkIf repoConfig.useDeterminateNix {
    systemd.tmpfiles.rules = [
      "z ${netrc} 0640 root ${group} - -"
    ];

    # PathChanged fires on close-after-write, which is how the daemon replaces
    # the file; chmod itself is IN_ATTRIB and does not retrigger the unit.
    systemd.paths.determinate-netrc-mode = {
      description = "Watch ${netrc} for credential rewrites";
      wantedBy = ["multi-user.target"];
      pathConfig.PathChanged = netrc;
    };

    systemd.services.determinate-netrc-mode = {
      description = "Restrict ${netrc} to root and ${group}";
      serviceConfig.Type = "oneshot";
      script = ''
        if [[ -e ${netrc} ]]; then
          chown root:${group} ${netrc}
          chmod 0640 ${netrc}
        fi
      '';
    };

    systemd.services.flakehub-token-expiry = {
      description = "Export the FlakeHub token expiry as a textfile metric";
      serviceConfig.Type = "oneshot";
      script = "${expiryMetric}/bin/flakehub-token-expiry";
    };

    systemd.timers.flakehub-token-expiry = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };
  }
