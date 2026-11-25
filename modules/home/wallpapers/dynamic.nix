# Condition-aware wallpaper selection on top of awww.
#
# Folders are runtime data: each collection is a directory under one of the
# roots, and the predicates below decide when it may be selected. The folder
# name is only a label, so `sunset/` and `dusk/` can coexist without a naming
# grammar. Images added to an existing folder need no rebuild.
#
# The selector publishes one stable copy (current.jpg in the first root) for
# consumers outside the session. Publication does not require a display: the
# timer runs whenever the user manager is up, and only the awww apply is
# skipped when no daemon answers.
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
  inherit (config) wallpapers;

  # The packaged crisp default and its blur twin, resolved once so the manifest
  # fallback and the activation seed cannot name different files.
  defaultWallpaperPath = "${wallpapers.wallpaperPath}/${wallpapers.available.${wallpapers.defaultWallpaper}}";
  defaultBlurredPath = "${wallpapers.wallpaperPath}/${wallpapers.availableBlurred.${wallpapers.defaultWallpaper}}";

  # awww's session target guarantees WAYLAND_DISPLAY. Fall back to niri's
  # target for the (unlikely) case where the awww module is not imported.
  sessionTarget = config.wm.awww.sessionTarget or "niri-session.target";

  manifest = pkgs.writeText "wallpaper-collections.json" (builtins.toJSON {
    inherit (cfg) roots;
    inherit (cfg) latitude;
    inherit (cfg) longitude;
    inherit (cfg) interval;
    weather = cfg.weather.enable;
    inherit (cfg) order;
    inherit (cfg) collections;
    inherit (cfg) publish;
    fallback = {
      file = defaultWallpaperPath;
      blurred = defaultBlurredPath;
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

    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3600;
      description = ''
        Seconds between image re-rolls inside the selected collection. The
        timer itself runs every ten minutes so dawn and dusk are followed;
        only the image changes on this interval.
      '';
    };

    publish = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if cfg.roots == []
        then null
        else "${builtins.head cfg.roots}/current.jpg";
      description = ''
        Stable JPEG copy of the selected crisp wallpaper, for consumers outside
        the session such as the homepage dashboard and the media kiosk. Defaults
        to current.jpg in the first root; set to null to disable publishing.
        The parent directory must already exist; the selector never creates a
        mountpoint.
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
      default = {
        # Unconstrained collection: the fallback when no constrained folder
        # matches. Daylight-only weather folders keep a daylit scene off the
        # night desktop; add a phase+weather folder (e.g. night-rain) for
        # night rain art.
        nature-studies = {};
        dawn = {phase = ["dawn"];};
        day = {phase = ["day"];};
        dusk = {phase = ["dusk"];};
        night = {phase = ["night"];};
        clear = {
          weather = ["clear" "partly"];
          phase = ["day"];
        };
        rain = {
          weather = ["rain" "thunder"];
          phase = ["day" "dawn" "dusk"];
        };
        snow = {
          weather = ["snow"];
          phase = ["day" "dawn" "dusk"];
        };
      };
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

    # Seed the consumer copy with the Nix default so the homepage has an image
    # before the first selector run. Never create the pool directory: while the
    # dataset is unmounted that would leave a shadow directory on the root
    # filesystem. The zz- prefix runs after writeBoundary and any earlier
    # home.file activation.
    home.activation.zz-wallpaper-current = lib.optionalString (cfg.publish != null) ''
      publish="${cfg.publish}"
      fallback="${defaultWallpaperPath}"
      if [ ! -e "$publish" ] && [ -f "$fallback" ] && [ -d "$(dirname "$publish")" ]; then
        cp "$fallback" "$publish"
        chmod 0644 "$publish"
      fi
    '';

    # Timer-driven run. It is deliberately bound to timers.target rather than
    # the session: on a lingering user manager it selects and publishes even
    # while no compositor runs, and the Python side applies to awww only when a
    # daemon answers.
    systemd.user.services.wallpaper-conditions = {
      Unit = {
        Description = "Apply the condition-aware wallpaper";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cli}/bin/wallpaper-conditions apply";
      };
    };

    # A new awww daemon starts on the default wallpaper, so the session unit
    # forces the current selection even when the state file already names it.
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
      };
      Timer = {
        OnCalendar = "*:0/10";
        Persistent = true;
        Unit = "wallpaper-conditions.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
