# Condition-aware wallpaper selection on top of awww.
#
# Folders are runtime data: each collection is a directory under one of the
# roots, and the predicates below decide when it may be selected. The folder
# name is only a label, so `sunset/` and `dusk/` can coexist without a naming
# grammar. Images added to an existing folder need no rebuild.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.wallpapers.dynamic;
  defaults = inputs.self.lib.defaults;
  package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wallpaper-conditions;

  # awww's session target guarantees WAYLAND_DISPLAY. Fall back to niri's
  # target for the (unlikely) case where the awww module is not imported.
  sessionTarget = config.wm.awww.sessionTarget or "niri-session.target";

  manifest = pkgs.writeText "wallpaper-collections.json" (builtins.toJSON {
    inherit (cfg) roots;
    inherit (cfg) latitude;
    inherit (cfg) longitude;
    weather = cfg.weather.enable;
    inherit (cfg) order;
    inherit (cfg) collections;
    fallback = {
      file = "${config.wallpapers.wallpaperPath}/${config.wallpapers.available.${config.wallpapers.defaultWallpaper}}";
      blurred = "${config.wallpapers.wallpaperPath}/${config.wallpapers.availableBlurred.${config.wallpapers.defaultWallpaper}}";
    };
  });

  # Bake the manifest into the CLI so the aliases and the timer do not repeat
  # a store path that changes on every rebuild.
  cli = pkgs.writeShellApplication {
    name = "wallpaper-conditions";
    runtimeInputs = [package];
    text = ''
      exec ${lib.getExe package} --manifest ${manifest} "$@"
    '';
  };
in {
  options.wallpapers.dynamic = {
    enable = lib.mkEnableOption "condition-aware wallpaper selection (requires awww)";

    roots = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["/per/mnt/data/media/pictures/wallpapers"];
      description = ''
        Directories that contain one folder per collection. They are scanned on
        every timer run, so adding images to an existing folder needs no
        rebuild. Absolute paths only; a missing root is reported by
        `wallpaper-conditions doctor` and falls back to the default wallpaper.
      '';
    };

    latitude = lib.mkOption {
      type = lib.types.float;
      default = defaults.location.latitude;
      defaultText = lib.literalExpression "inputs.self.lib.defaults.location.latitude";
      description = "Latitude used to classify dawn, day, dusk and night.";
    };

    longitude = lib.mkOption {
      type = lib.types.float;
      default = defaults.location.longitude;
      defaultText = lib.literalExpression "inputs.self.lib.defaults.location.longitude";
      description = "Longitude used to classify dawn, day, dusk and night.";
    };

    weather = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Fetch the current weather code from Open-Meteo (no API key). When the
          network is unavailable the last observation is reused for a few
          hours, then selection falls back to phase only.
        '';
      };
    };

    order = lib.mkOption {
      type = lib.types.listOf (lib.types.enum ["phase" "weather"]);
      default = ["phase" "weather"];
      description = ''
        Tie-break order when two matching collections constrain the same number
        of dimensions, e.g. a phase-only `night` folder and a weather-only
        `rain` folder on a rainy night. Phase first keeps daylight art off the
        night desktop; put weather first when weather should dominate.
      '';
    };

    collections = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          phase = lib.mkOption {
            type = lib.types.listOf (lib.types.enum ["dawn" "day" "dusk" "night"]);
            default = [];
            description = "Solar phases this folder is valid for; empty means any.";
          };
          weather = lib.mkOption {
            type = lib.types.listOf (lib.types.enum [
              "clear"
              "partly"
              "overcast"
              "fog"
              "rain"
              "snow"
              "thunder"
            ]);
            default = [];
            description = "Weather categories this folder is valid for; empty means any.";
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = ''
              Breaks ties between collections with the same specificity and
              dimension order; higher wins. Use it when two folders are valid
              for the same conditions, e.g. a generic rain/ and a dawn-rain/.
            '';
          };
        };
      });
      default = {};
      description = ''
        Folder name -> conditions. The attribute name is the folder under each
        root; the predicates are the conditions it may be selected for. A
        collection with no predicates is the fallback and is only picked when
        no constrained collection matches. The folder name is not parsed, so
        it can be any label that matches [A-Za-z0-9_-]+.
      '';
      example = lib.literalExpression ''
        {
          night = {phase = ["night"];};
          clear = {weather = ["clear" "partly"]; phase = ["day"];};
          rain = {weather = ["rain" "thunder"]; phase = ["day" "dawn" "dusk"];};
          snow = {weather = ["snow"];};
          default = {};
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.wm.awww.enable or false;
        message = "wallpapers.dynamic requires wm.awww.enable; awww owns the wallpaper on this host.";
      }
      {
        assertion = cfg.roots != [];
        message = "wallpapers.dynamic.roots must list at least one wallpaper root.";
      }
      {
        assertion = lib.sort (a: b: a < b) cfg.order == lib.sort (a: b: a < b) ["phase" "weather"];
        message = "wallpapers.dynamic.order must contain phase and weather exactly once each.";
      }
      {
        assertion = lib.all (name: builtins.match "[A-Za-z0-9_-]+" name != null) (lib.attrNames cfg.collections);
        message = "wallpapers.dynamic.collections names must match [A-Za-z0-9_-]+.";
      }
    ];

    home.packages = [cli];

    home.shellAliases = {
      wallpaper-status = "wallpaper-conditions status";
      wallpaper-next = "wallpaper-conditions next";
    };

    # Timer-driven run. The session-start unit below forces the selection even
    # when the previous session left the same image in the state file, because
    # a new awww daemon starts on the default wallpaper.
    systemd.user.services.wallpaper-conditions = {
      Unit = {
        Description = "Apply the condition-aware wallpaper";
        After = [sessionTarget "awww-wallpaper-init.service"];
        Wants = ["awww-wallpaper-init.service"];
        PartOf = [sessionTarget];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cli}/bin/wallpaper-conditions apply";
      };
    };

    systemd.user.services.wallpaper-conditions-session = {
      Unit = {
        Description = "Apply the condition-aware wallpaper at session start";
        After = [sessionTarget "awww-wallpaper-init.service"];
        Wants = ["awww-wallpaper-init.service"];
        PartOf = [sessionTarget];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cli}/bin/wallpaper-conditions apply --force";
      };
      Install.WantedBy = [sessionTarget];
    };

    # Ten minutes is enough to follow dawn and dusk without polling the
    # weather API more often than the conditions change.
    systemd.user.timers.wallpaper-conditions = {
      Unit = {
        Description = "Periodic condition-aware wallpaper check";
        PartOf = [sessionTarget];
      };
      Timer = {
        OnCalendar = "*:0/10";
        Persistent = true;
        Unit = "wallpaper-conditions.service";
      };
      Install.WantedBy = [sessionTarget];
    };
  };
}
