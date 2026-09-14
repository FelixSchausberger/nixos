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

  # Detector bundle: exactly the two files the post-deploy detector needs.
  # detect-downgrades.sh sources its sibling lib-downgrade-compare.sh at
  # runtime via BASH_SOURCE, so both must land in the store together — but the
  # whole scripts directory would ship unrelated tooling into every closure.
  detectorBundle = pkgs.runCommand "comin-downgrade-detector" {} ''
    mkdir -p $out
    cp ${../../tools/scripts/detect-downgrades.sh} $out/detect-downgrades.sh
    cp ${../../tools/scripts/lib-downgrade-compare.sh} $out/lib-downgrade-compare.sh
  '';

  # Wrapper bridges comin's postDeploymentCommand hook (absolute path, no
  # arguments) to the repo detector script and its ntfy configuration.
  postDeploy = pkgs.writeShellApplication {
    name = "comin-post-deployment";
    runtimeInputs = with pkgs; [coreutils curl nix];
    text = ''
      export COMIN_NTFY_URL=${lib.escapeShellArg (toString cfg.alertNtfyUrl)}
      exec ${pkgs.bash}/bin/bash ${detectorBundle}/detect-downgrades.sh
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

    localRemote = {
      enable = lib.mkEnableOption ''
        local polling remote for fast iteration on a development host.
        comin fetches the colocated checkout directly and applies its
        testing-<hostname> branch with switch-to-configuration test -
        without touching the bootloader and without a GitHub round trip.
        The checkout is user-writable, so any process that can move the
        testing bookmark can cause comin to build and activate code.
      '';

      path = lib.mkOption {
        type = lib.types.path;
        default = "/per/etc/nixos";
        description = "Colocated checkout polled for the testing branch";
      };

      pollPeriod = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Seconds between fetches of the local checkout";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.comin = {
        enable = true;
        # Upstream default is 1800s and applies to the whole build, not per
        # derivation: a single derivation larger than the timeout gets killed
        # and restarted from scratch every poll, wedging convergence forever
        # (FreeCAD-sized builds need hours).
        buildTimeout = 7200;
        remotes =
          [
            {
              name = "origin";
              url = cfg.remoteUrl;
              poller.period = cfg.pollPeriod;
              branches = {
                # main is the durable channel: always switched.
                main = {
                  name = "main";
                  operation = "switch";
                };
                # Testing is served by the local remote only. Disabling it
                # here keeps a stray GitHub testing branch from being selected.
                testing.name = "";
              };
            }
          ]
          ++ lib.optional cfg.localRemote.enable {
            name = "local";
            url = toString cfg.localRemote.path;
            poller.period = cfg.localRemote.pollPeriod;
            branches = {
              # No main on the local remote: origin/main stays the single
              # source of truth. `jjtest` sets testing-<hostname> on top of it.
              main.name = "";
              testing = {
                name = "testing-${config.networking.hostName}";
                operation = "test";
              };
            };
          };
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
    })
  ];
}
