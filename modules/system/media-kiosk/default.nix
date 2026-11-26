# Controller-first media kiosk for the projector session.
#
# The kiosk is a normal fullscreen browser window inside the on-demand niri
# session, not a gamescope or second-compositor session: UxPlay must be able to
# open a fullscreen window over it, and the AirPlay receiver is bound to
# niri-session.target.
#
# This module owns the small action/preview HTTP service. The browser itself is
# a Home Manager user service (modules/home/gui/media-kiosk.nix) because it must
# use the Home-Manager-wrapped Zen package, whose installation policies carry
# uBlock Origin for Cinejoy.
#
# The service is deliberately a thin local API rather than a maintained kiosk
# product: OpenGamepadUI owns a gamescope session and cannot host Jellyfin,
# Immich or Cinejoy; Kodi covers only Jellyfin; Homepage is read-only; Steam
# would add a login and a global Steam Input desktop layout. No maintained tool
# covers this flow set inside a shared niri session.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.mediaKiosk;

  # nixpkgs' Jellyfin module has no port option and keeps the upstream 8096.
  jellyfinPort = 8096;

  # The kiosk renders the desktop's wallpaper. The live copy is the file the
  # condition-aware selector publishes; the packaged crisp default remains the
  # fallback while the pool is unmounted or before the first selection.
  backgroundFile =
    inputs.self.lib.wallpapers.available.${inputs.self.lib.wallpapers.default}
    or (throw "lib/wallpapers.nix has no file for '${inputs.self.lib.wallpapers.default}'");

  kioskPackage = pkgs.callPackage ./package.nix {
    wallpaper = ../../../modules/home/wallpapers/${backgroundFile};
  };

  # The API keys never reach the browser. sops renders them into a user-owned
  # environment file; the underlying secrets stay root-owned and at their
  # existing permissions. The Immich preview needs a scoped key (asset.read +
  # asset.view); the Homepage key only grants /api/server/statistics.
  immichKeyName =
    if cfg.immichKioskApiKeySecret == null
    then "immich/homepage-api-key"
    else cfg.immichKioskApiKeySecret;

  configFile = pkgs.writeText "media-kiosk-config.json" (builtins.toJSON {
    inherit (cfg) port;
    bind = "127.0.0.1";
    inherit (cfg) cacheDir;
    inherit (cfg) wallpaperFile;
    jellyfin = {
      url = "http://127.0.0.1:${toString jellyfinPort}";
    };
    immich = {
      url = "http://127.0.0.1:${toString config.modules.system.homelab.immich.port}";
    };
    cinejoy = {
      url = cfg.cinejoyUrl;
    };
    desktop = {
      host = cfg.desktopHost;
      app = cfg.moonlightApp;
      port = 47989;
      power = lib.getExe cfg.desktopPower;
      moonlight = lib.getExe cfg.moonlightPackage;
    };
    audio = {
      url = cfg.audioHubUrl;
    };
    systemd = {
      systemctl = lib.getExe' pkgs.systemd "systemctl";
      inherit (cfg) browserUnit;
    };
    niri = {
      bin = lib.getExe config.programs.niri.package;
    };
    open = {
      # Home-Manager installs this helper next to the kiosk browser profile;
      # it opens app URLs in a chromeless top-level Zen window.
      command = "/home/${cfg.user}/.local/bin/kiosk-open";
    };
  });
in {
  options.modules.system.mediaKiosk = {
    enable = lib.mkEnableOption "controller-first media kiosk for the projector session";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hostConfig.user;
      description = "User owning the kiosk user services";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.mediaKiosk;
      description = "Loopback HTTP port for the kiosk API";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/per/var/kiosk/cache";
      description = "Persistent directory for the Jellyfin/Immich preview cache";
    };

    wallpaperFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/per/mnt/data/media/pictures/wallpapers/current.jpg";
      description = ''
        Live wallpaper served at /static/wallpaper.jpg, normally the file
        published by the condition-aware selector. When it is absent the
        kiosk falls back to the packaged default wallpaper.
      '';
    };

    desktopPower = lib.mkOption {
      type = lib.types.package;
      description = ''
        The host's desktop-power package, passed in so the Moonlight tile wakes
        the desktop through the existing WoL + ping + ntfy path instead of
        duplicating that logic.
      '';
    };

    desktopHost = lib.mkOption {
      type = lib.types.str;
      default = inputs.self.lib.hosts.desktop.ip;
      description = "Desktop running Moonshine, used for Moonlight and wake";
    };

    moonlightPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.moonlight-qt;
      description = "Moonlight package providing the stream CLI";
    };

    moonlightApp = lib.mkOption {
      type = lib.types.str;
      default = "Steam";
      description = "Moonshine application title started by the Steam stream tile";
    };

    cinejoyUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cinejoy.pk/";
      description = "Cinejoy URL opened in a top-level kiosk window";
    };

    audioHubUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8765";
      description = ''
        Base URL of the shared audio-router service owned by the audio hub.
        The kiosk only forwards /status and /output/<id>; an absent hub is a
        degraded UI, not an error.
      '';
    };

    browserUnit = lib.mkOption {
      type = lib.types.str;
      default = "media-kiosk-browser.service";
      description = "User unit the Exit kiosk action stops";
    };

    immichKioskApiKeySecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "immich/kiosk-api-key";
      description = ''
        sops secret holding a scoped Immich key with asset.read and asset.view.
        Set to null to fall back to the statistics-only
        immich/homepage-api-key (the preview then stays static art).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.niri.enable;
        message = "modules.system.mediaKiosk runs inside the niri session";
      }
      {
        assertion = config.modules.system.homelab.jellyfin.enable;
        message = "modules.system.mediaKiosk expects the Jellyfin module (live resume preview)";
      }
      {
        assertion = config.modules.system.homelab.immich.enable;
        message = "modules.system.mediaKiosk expects the Immich module (live recent-photo preview)";
      }
      {
        assertion = config.sops.secrets ? "jellyfin/api-key";
        message = "modules.system.mediaKiosk needs the existing sops jellyfin/api-key for the resume preview";
      }
      {
        assertion = config.sops.secrets ? "immich/homepage-api-key";
        message = "modules.system.mediaKiosk needs the Immich module's sops immich/homepage-api-key";
      }
      {
        assertion = builtins.elem "input" config.users.users.${cfg.user}.extraGroups;
        message = "modules.system.mediaKiosk's Valve hidraw rule needs the kiosk user in the input group (the on-demand session module adds it)";
      }
    ];

    # The preview keys and the web-login credentials are declared here, next to
    # their only consumer. They must exist in secrets/secrets.yaml before
    # activation; the underlying files stay root-owned and the rendered
    # environment file is user-owned.
    sops.secrets =
      {
        "jellyfin/password" = {};
        "immich/admin-email" = {};
        "immich/admin-password" = {};
      }
      // lib.optionalAttrs (cfg.immichKioskApiKeySecret != null) {
        ${cfg.immichKioskApiKeySecret} = {};
      };

    sops.templates."media-kiosk/env" = {
      content = ''
        JELLYFIN_API_KEY=${config.sops.placeholder."jellyfin/api-key"}
        JELLYFIN_USER=jellyfin
        JELLYFIN_PASSWORD=${config.sops.placeholder."jellyfin/password"}
        IMMICH_API_KEY=${config.sops.placeholder.${immichKeyName}}
        IMMICH_EMAIL=${config.sops.placeholder."immich/admin-email"}
        IMMICH_PASSWORD=${config.sops.placeholder."immich/admin-password"}
      '';
      path = "/run/secrets/media-kiosk/env";
      owner = cfg.user;
      mode = "0400";
      # The API reads the keys once per service start. A rotation takes effect
      # on the next session (or a manual restart); no restartUnits entry can
      # target a user unit from the root activation context.
    };

    systemd.user.services.media-kiosk-api = {
      description = "Media kiosk action and preview API";
      after = ["niri-session.target"];
      partOf = ["niri-session.target"];
      bindsTo = ["niri-session.target"];
      wantedBy = ["niri-session.target"];
      serviceConfig = {
        ExecStart = lib.getExe kioskPackage;
        Environment = ["KIOSK_CONFIG=${configFile}"];
        EnvironmentFile = [config.sops.templates."media-kiosk/env".path];
        WorkingDirectory = "%h";
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutStopSec = 5;
        # Preview images may contain personal photos; keep the cache and any
        # files the service creates private to the kiosk user.
        UMask = "0077";
      };
    };

    systemd.tmpfiles.rules = [
      "d /per/var/kiosk 0755 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
      "d ${cfg.cacheDir} 0700 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
    ];

    # The 2026 Steam Controller is claimed by SDL3 through its vendor hidraw
    # interface. Valve's steam-hardware rules only add TAG+="uaccess", which
    # logind applies to logged-in sessions; this host starts niri from seatd
    # with no logind session, so hidraw would stay root:root and SDL3 could not
    # open the controller. Grant the input group (the on-demand session module
    # already puts the kiosk user there) read/write access instead. Lizard-mode
    # keyboard/mouse is unaffected.
    services.udev.extraRules = ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
      SUBSYSTEM=="hidraw", KERNELS=="000[356]:28DE:*", MODE="0660", GROUP="input"
    '';
  };
}
