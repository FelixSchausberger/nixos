{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.garmin;
  hl = config.modules.system.homelab;
  inherit (lib) mkIf;

  # Local InfluxQL endpoint of the GarminStats database. InfluxDB v1 HTTP
  # accepts the database name as a query parameter, so the datasource needs
  # no database-scoped credentials.
  influxUrl = "http://127.0.0.1:${toString hl.garmin.influxPort}";
  # Fetcher environment. Credentials are interpolated from sops placeholders
  # into a root-owned EnvironmentFile (0640, group garmin-fetch), following
  # the grafana-env template pattern in monitoring.nix. The upstream script
  # expects the password base64-encoded (GARMINCONNECT_BASE64_PASSWORD) to
  # keep it out of compose plaintext; the sops secret already stores the
  # base64 form, so no runtime encoding step is needed.

  # The pip console script (lib.getExe's target) calls main(), but upstream's
  # main() only does `from . import garmin_fetch` while the whole engine
  # (login, MFA prompt, fetch loop) sits behind `if __name__ == "__main__":`
  # in garmin_fetch.py. On import that gate is false, so the script printed
  # its banner and exited 0 without ever authenticating. Upstream's Docker
  # image works around this by running the .py file as a script; executing
  # the module as __main__ through runpy reproduces that from the console
  # script. --replace-fail makes the build fail loudly if upstream rewrites
  # the line, instead of silently regressing to the no-op entry point.
  garmin-grafana = pkgs.garmin-grafana.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/garmin_grafana/__init__.py \
          --replace-fail 'from . import garmin_fetch' \
          'import runpy; runpy.run_module("garmin_grafana.garmin_fetch", run_name="__main__")'
      '';
  });
in {
  options.modules.system.homelab.garmin = {
    enable = lib.mkEnableOption ''
      Garmin health-data pipeline: InfluxDB 1.x store, garmin-grafana fetcher,
      and a provisioned Grafana dashboard. Requires monitoring.enable.
    '';
    influxPort = lib.mkOption {
      type = lib.types.port;
      default = 8087;
      description = "InfluxDB HTTP port for the GarminStats database (loopback only)";
    };
    calendar = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = hl.nextcloud.enable;
        defaultText = lib.literalExpression "config.modules.system.homelab.nextcloud.enable";
        description = ''
          Overlay Nextcloud calendar events on Grafana dashboards as
          annotations. Requires nextcloud.enable.
        '';
      };
      # Default Nextcloud CalDAV principal: the instance has a single admin
      # user and its default personal calendar (named "personal"), matching
      # the admin-user occ calls in nextcloud.nix.
      user = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Nextcloud user whose default personal calendar is synced";
      };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "15min";
        description = "How often calendar events are synced into Grafana annotations";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hl.monitoring.enable;
        message = "modules.system.homelab.garmin requires modules.system.homelab.monitoring.enable = true (dashboard is provisioned there)";
      }
      {
        assertion = !cfg.calendar.enable || hl.nextcloud.enable;
        message = "modules.system.homelab.garmin.calendar requires modules.system.homelab.nextcloud.enable = true";
      }
      {
        assertion = cfg.influxPort != hl.monitoring.prometheusPort;
        message = "Garmin InfluxDB port must differ from the Prometheus port";
      }
    ];

    # InfluxDB 1.x (not v2/v3): the garmin-grafana fetcher and its ready-made
    # dashboard query InfluxQL (upstream targets 1.11; v3 OSS caps query
    # windows at 72 hours, defeating the long-term-trend purpose). A marker-
    # gated oneshot provisions the GarminStats database and its user once
    # InfluxDB is up; auth is enabled and bound to loopback only.
    services.influxdb = {
      enable = true;
      settings.http = {
        bind-address = ":${toString cfg.influxPort}";
        auth-enabled = true;
      };
    };

    # Provision the fetcher's database user after InfluxDB is up. Gated to
    # run once (marker file in the InfluxDB state dir); a password change
    # afterwards means removing the marker and restarting the unit.
    systemd.services.influxdb-garmin-setup = {
      description = "Provision the GarminStats database user for the Garmin fetcher";
      after = ["influxdb.service"];
      requires = ["influxdb.service"];
      wantedBy = ["influxdb.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = "influx-user-password:${config.sops.secrets."garmin/influx-user-password".path}";
      };
      script = ''
        set -euo pipefail
        marker="${config.services.influxdb.dataDir}/.garmin-provisioned"
        if [ -e "$marker" ]; then
          exit 0
        fi
        password="$(cat "$CREDENTIALS_DIRECTORY/influx-user-password")"
        until ${pkgs.curl}/bin/curl -sf -o /dev/null "${influxUrl}/ping"; do
          sleep 1
        done
        # InfluxDB v1 permits exactly one statement while no user exists:
        # the first CREATE USER, which becomes the admin. CREATE DATABASE is
        # rejected before that ("create admin user first"), and IF NOT EXISTS
        # is not valid influxql, so the user comes first and the database is
        # created authenticated as that user. A failed CREATE USER means the
        # user already exists (partial earlier run); the SHOW probe verifies
        # it authenticates rather than masking the error.
        if ! ${pkgs.influxdb}/bin/influx -host 127.0.0.1 -port ${toString cfg.influxPort} \
          -execute "CREATE USER \"garmin\" WITH PASSWORD '$password' WITH ALL PRIVILEGES"; then
          ${pkgs.influxdb}/bin/influx -host 127.0.0.1 -port ${toString cfg.influxPort} \
            -username garmin -password "$password" \
            -execute "SHOW DATABASES" > /dev/null
        fi
        ${pkgs.influxdb}/bin/influx -host 127.0.0.1 -port ${toString cfg.influxPort} \
          -username garmin -password "$password" \
          -execute "CREATE DATABASE \"GarminStats\""
        touch "$marker"
      '';
    };

    # Garmin Connect fetcher: long-running poller writing health metrics,
    # activities and GPS tracks into InfluxDB. Credentials come from sops;
    # the first start needs ONE interactive MFA step (see garmin-login below),
    # afterwards the OAuth tokens in the persisted state directory refresh
    # automatically.
    users.users.garmin-fetch = {
      isSystemUser = true;
      group = "garmin-fetch";
    };
    users.groups.garmin-fetch = {};

    sops.secrets = {
      "garmin/email".owner = "garmin-fetch";
      "garmin/base64-password".owner = "garmin-fetch";
      # garmin/influx-user-password is declared only by monitoring.nix, which
      # sets owner grafana: Grafana reads the file via $__file{} at query
      # time. The consumers here need no file ownership — the fetcher gets
      # the value through the rendered template (activated as root) and
      # influxdb-garmin-setup reads it via LoadCredential (root).
      "nextcloud/calendar-app-password".owner = mkIf cfg.calendar.enable "garmin-fetch";
    };
    sops.templates."garmin/env" = {
      content = ''
        GARMINCONNECT_EMAIL=${config.sops.placeholder."garmin/email"}
        GARMINCONNECT_BASE64_PASSWORD=${config.sops.placeholder."garmin/base64-password"}
        INFLUXDB_VERSION=1
        INFLUXDB_HOST=127.0.0.1
        INFLUXDB_PORT=${toString cfg.influxPort}
        INFLUXDB_USERNAME=garmin
        INFLUXDB_PASSWORD=${config.sops.placeholder."garmin/influx-user-password"}
        INFLUXDB_DATABASE=GarminStats
        USER_TIMEZONE=${config.time.timeZone}
      '';
      owner = "garmin-fetch";
      path = "/run/secrets/garmin/env";
      mode = "0400";
    };
    sops.templates."garmin-calendar/env" = mkIf cfg.calendar.enable {
      content = ''
        NC_URL=http://127.0.0.1:${toString hl.nextcloud.port}
        NC_USER=${cfg.calendar.user}
        NC_APP_PASSWORD=${config.sops.placeholder."nextcloud/calendar-app-password"}
        GRAFANA_URL=http://127.0.0.1:${toString hl.monitoring.grafanaPort}
        GRAFANA_TOKEN=${config.sops.placeholder."grafana/calendar-annotation-token"}
      '';
      owner = "garmin-fetch";
      path = "/run/secrets/garmin-calendar/env";
      mode = "0400";
    };

    systemd.services.garmin-fetch-data = {
      description = "Garmin Connect to InfluxDB health-data fetcher";
      after = ["influxdb-garmin-setup.service" "sops-nix.service"];
      requires = ["influxdb.service"];
      wants = ["sops-nix.service"];
      wantedBy = ["multi-user.target"];
      # Garmin rate-limits aggressively; a slow restart loop is deliberate.
      unitConfig = {
        StartLimitBurst = 5;
        StartLimitIntervalSec = 600;
        # The OAuth token store only exists after the one-time MFA login
        # (garmin-login helper below); without it the fetcher cannot
        # authenticate, so the unit stays dormant instead of burning its
        # restart limit on every boot.
        ConditionPathExists = "/var/lib/garmin-fetch/garminconnect-tokens";
      };
      serviceConfig = {
        Type = "exec";
        User = "garmin-fetch";
        Group = "garmin-fetch";
        EnvironmentFile = config.sops.templates."garmin/env".path;
        ExecStart = "${lib.getExe garmin-grafana}";
        Restart = "on-failure";
        RestartSec = "5min";
        StateDirectory = "garmin-fetch";
        # TOKEN_DIR must be absolute; the upstream default (~/.garminconnect)
        # does not survive a systemd-privatized /home.
        Environment = "TOKEN_DIR=/var/lib/garmin-fetch/garminconnect-tokens";
        ReadWritePaths = ["/var/lib/garmin-fetch"];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    # One-shot interactive login helper. Garmin MFA cannot be automated via
    # env (upstream uses prompt_mfa, commit 6720ed9, to avoid login
    # rate-limiting), so the MFA code is typed once by the user; the OAuth
    # token store persists under /var/lib/garmin-fetch before any fetch runs
    # and auto-refreshes afterwards. MANUAL_START_DATE selects upstream's
    # bulk-then-exit path: after MFA the helper fetches today's data once
    # and exits 0 instead of entering the endless poll loop, so a later run
    # never collides with a still-running unit. Manual invocation is:
    #   sudo systemd-run --pty -p User=garmin-fetch -p Group=garmin-fetch \
    #     -p EnvironmentFile=/run/secrets/garmin/env \
    #     -p Environment=TOKEN_DIR=/var/lib/garmin-fetch/garminconnect-tokens \
    #     -p Environment=MANUAL_START_DATE=$(date +%F) \
    #     ${lib.getExe garmin-grafana}
    environment.systemPackages = lib.mkIf config.modules.system.homelab.monitoring.enable [
      (pkgs.writeShellApplication {
        name = "garmin-login";
        runtimeInputs = with pkgs; [coreutils systemd];
        text = ''
          # Re-creates the Garmin OAuth token store interactively (MFA code
          # prompt). Must run on m920q; tokens land in /var/lib/garmin-fetch
          # and unblock garmin-fetch-data, which stays dormant
          # (ConditionPathExists) until they exist: start it explicitly
          # after login, or let the next boot pick it up. MANUAL_START_DATE
          # makes the engine bulk-fetch today's data and exit instead of
          # polling forever.
          exec systemd-run --pty \
            --unit=garmin-login \
            -p User=garmin-fetch -p Group=garmin-fetch \
            -p EnvironmentFile="${config.sops.templates."garmin/env".path}" \
            -p Environment=TOKEN_DIR=/var/lib/garmin-fetch/garminconnect-tokens \
            -p "Environment=MANUAL_START_DATE=$(date +%F)" \
            -p StateDirectory=garmin-fetch \
            ${lib.getExe garmin-grafana}
        '';
      })
    ];

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/garmin-fetch";
        user = "garmin-fetch";
        group = "garmin-fetch";
        mode = "0700";
      }
    ];

    # Nextcloud calendar → Grafana annotations. Server-side fetch of the
    # default personal calendar's ICS export (CalDAV), pushed through
    # Grafana's annotations API so events mark every metric timeline. This
    # avoids the browser-side CORS constraints of the calendar-panel plugin.
    systemd.services.garmin-calendar-sync = mkIf cfg.calendar.enable {
      description = "Sync Nextcloud calendar events into Grafana annotations";
      after = ["nextcloud-setup.service" "grafana.service"];
      wants = ["grafana.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "garmin-fetch";
        Group = "garmin-fetch";
        EnvironmentFile = config.sops.templates."garmin-calendar/env".path;
      };
      script = ''
        exec ${inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.garmin-calendar-sync}/bin/garmin-calendar-sync
      '';
    };
    systemd.timers.garmin-calendar-sync = mkIf cfg.calendar.enable {
      description = "Periodic Nextcloud calendar to Grafana annotation sync";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.calendar.interval;
        RandomizedDelaySec = "30s";
      };
    };
  };
}
