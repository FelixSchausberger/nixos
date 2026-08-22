# Pull-based GitOps deployment via comin.
#
# flake.lock has a single writer: the daily-updates GitHub Actions workflow
# (daily cron, on-demand through update-system.sh). Hosts poll the public
# GitHub main branch and deploy nixosConfigurations.<hostname> automatically;
# store paths mostly substitute from cachix, warmed by
# .github/workflows/cachix-push.yml after every merge.
#
# The interactive deploy path (nh.nix aliases) keeps guard-downgrades.sh as a
# blocking check. This automated path cannot block - a blocked host would go
# stale while unattended - so regressions are detected after deployment by
# detect-downgrades.sh and reported to ntfy. A bad lock is healed by
# reverting its commit on main, after which every host converges back.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.modules.system.comin;

  # Wrapper bridges comin's postDeploymentCommand hook (absolute path, no
  # arguments) to the repo detector script and its ntfy configuration.
  postDeploy = pkgs.writeShellApplication {
    name = "comin-post-deployment";
    runtimeInputs = with pkgs; [coreutils curl nix];
    text = ''
      export COMIN_NTFY_URL=${lib.escapeShellArg (toString cfg.alertNtfyUrl)}
      exec ${pkgs.bash}/bin/bash ${../../tools/scripts/detect-downgrades.sh}
    '';
  };
in {
  imports = [inputs.comin.nixosModules.comin];

  options.modules.system.comin = {
    enable = lib.mkEnableOption "comin pull-based GitOps deployment";

    remoteUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/FelixSchausberger/nixos.git";
      description = "Git repository polled by comin for new main commits";
    };

    pollPeriod = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds between git fetches of the remote main branch";
    };

    alertNtfyUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        ntfy URL receiving package downgrade alerts after automated
        deployments. Unset logs detections to the journal instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = cfg.remoteUrl;
          poller.period = cfg.pollPeriod;
        }
      ];
      postDeploymentCommand = lib.getExe postDeploy;
    };

    # Deployment history and the repository clone live here; losing them on
    # an impermanence system would re-deploy the same commit on every boot
    # and discard rollback state.
    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/comin";
        user = "root";
        group = "root";
        mode = "0750";
      }
    ];
  };
}
