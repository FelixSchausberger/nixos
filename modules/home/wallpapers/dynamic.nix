# Condition-aware wallpaper selection on top of awww.
#
# A theme is a family of collection folders under the pool, e.g.
# <root>/plants/<collection>. The predicates decide when a collection may be
# selected; the folder name is only a label. Images added to an existing
# folder need no rebuild.
#
# The selector publishes one stable copy (current.jpg in the first root) for
# consumers outside the session. The active theme is shared through
# active-theme in the same root, so a host that only mounts the pool read-only
# follows the host that writes it. Publication does not require a display: the
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

  collectionType = lib.types.attrsOf (lib.types.submodule {
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

  defaultCollections = {
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

  manifest = pkgs.writeText "wallpaper-collections.json" (builtins.toJSON {
    inherit (cfg) roots;
    inherit (cfg) latitude;
    inherit (cfg) longitude;
    inherit (cfg) interval;
    weather = cfg.weather.enable;
    inherit (cfg) order;
    inherit (cfg) publish;
    default_theme = cfg.defaultTheme;
    active_theme_file = cfg.activeThemeFile;
    themes =
      lib.mapAttrs (name: theme: {
        roots =
          if theme.roots == []
          then map (root: "${root}/${name}") cfg.roots
          else theme.roots;
        inherit (theme) collections;
      })
      cfg.themes;
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
        Pool roots. Each theme lives in a subdirectory named after it
        (`<root>/<theme>/<collection>`), unless the theme overrides its roots.
        They are scanned on every timer run, so adding images to an existing
        folder needs no rebuild. Absolute paths only; a missing root is
        reported by `wallpaper-conditions doctor` and falls back to the
        default wallpaper.
      '';
    };

    themes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          roots = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Directories holding this theme's collection folders. Empty means
              `<root>/<theme>` for every pool root; set it when a theme lives
              on another mount, such as a local laptop cache.
            '';
          };
          collections = lib.mkOption {
            type = collectionType;
            description = "Folder name -> conditions inside this theme.";
          };
        };
      });
      default = {
        landscapes = {collections = defaultCollections;};
        plants = {collections = {any = {};};};
        ascii = {collections = {any = {};};};
      };
      description = ''
        Theme family -> its collection folders. The folder name is not parsed,
        so it can be any label that matches [A-Za-z0-9_-]+. Switch the active
        theme at runtime with `wallpaper-theme <name>`; the choice is shared
        through activeThemeFile.
      '';
    };

    defaultTheme = lib.mkOption {
      type = lib.types.str;
      default = "landscapes";
      description = "Theme used when neither the shared file nor the local state names one.";
    };

    activeThemeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if cfg.roots == []
        then null
        else "${builtins.head cfg.roots}/active-theme";
      description = ''
        Shared file holding the active theme name, normally in the pool root.
        The host that mounts the pool read-write (the laptop) writes it; hosts
        that only read the pool follow it. Set to null to keep the choice local
        to each host.
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
        assertion = builtins.hasAttr cfg.defaultTheme cfg.themes;
        message = "wallpapers.dynamic.defaultTheme must name a declared theme.";
      }
      {
        assertion = lib.all (name: builtins.match "[A-Za-z0-9_-]+" name != null) (lib.attrNames cfg.themes);
        message = "wallpapers.dynamic.themes names must match [A-Za-z0-9_-]+.";
      }
      {
        assertion = lib.all (
          theme: lib.all (name: builtins.match "[A-Za-z0-9_-]+" name != null) (lib.attrNames theme.collections)
        ) (lib.attrValues cfg.themes);
        message = "wallpapers.dynamic collections names must match [A-Za-z0-9_-]+.";
      }
    ];

    home.packages = [cli];

    home.shellAliases = {
      wallpaper-status = "wallpaper-conditions status";
      wallpaper-next = "wallpaper-conditions next";
      wallpaper-theme = "wallpaper-conditions theme";
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
