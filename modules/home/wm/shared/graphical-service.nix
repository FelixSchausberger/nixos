# Reusable wrapper for graphical-session-aware systemd user services
#
# This module provides a declarative API for defining services that:
# - Only start when graphical-session.target is active
# - Stop when the graphical session ends
# - Have proper environment propagation via UWSM
#
# Usage:
#   modules.home.graphicalService.myservice = {
#     enable = true;
#     description = "My graphical service";
#     execStart = "${pkgs.myapp}/bin/myapp";
#   };
{
  lib,
  config,
  ...
}: {
  options.modules.home.graphicalService = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      options = {
        enable = lib.mkEnableOption "graphical service ${name}";

        description = lib.mkOption {
          type = lib.types.str;
          description = "Service description";
        };

        execStart = lib.mkOption {
          type = lib.types.str;
          description = "ExecStart command";
        };

        serviceType = lib.mkOption {
          type = lib.types.enum ["simple" "oneshot" "forking" "notify"];
          default = "simple";
          description = "Systemd service type";
        };

        restart = lib.mkOption {
          type = lib.types.enum ["no" "on-failure" "on-success" "always"];
          default = "on-failure";
          description = "Restart policy";
        };

        restartSec = lib.mkOption {
          type = lib.types.str;
          default = "5s";
          description = "Time to wait before restart";
        };

        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Environment variables";
        };

        requires = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Required services";
        };

        after = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Services to start after";
        };

        partOf = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Stop service when graphical session ends";
        };

        execStartPre = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Command to run before ExecStart";
        };

        execStopPost = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Command to run after service stops";
        };
      };
    }));
    default = {};
    description = "Graphical session-aware systemd user services";
  };

  config.systemd.user.services = lib.mapAttrs (_name: cfg:
    lib.mkIf cfg.enable {
      Unit =
        {
          Description = cfg.description;
          After = ["graphical-session.target"] ++ cfg.after;
          Requires = cfg.requires;
        }
        // lib.optionalAttrs cfg.partOf {
          PartOf = ["graphical-session.target"];
        };

      Service =
        {
          Type = cfg.serviceType;
          ExecStart = cfg.execStart;
          Restart = cfg.restart;
          RestartSec = cfg.restartSec;
        }
        // lib.optionalAttrs (cfg.environment != {}) {
          Environment = lib.mapAttrsToList (k: v: "${k}=${v}") cfg.environment;
        }
        // lib.optionalAttrs (cfg.execStartPre != null) {
          ExecStartPre = cfg.execStartPre;
        }
        // lib.optionalAttrs (cfg.execStopPost != null) {
          ExecStopPost = cfg.execStopPost;
        };

      Install.WantedBy = ["graphical-session.target"];
    })
  config.modules.home.graphicalService;
}
