# Zen kiosk profile and session browser.
#
# This is a second managed profile, not the default one: the default profile
# carries the declarative essential pins, and Home Manager rewrites
# zen-sessions.jsonlz4 for it while activation requires Zen to be closed. The
# kiosk profile has no pins, spaces or session data, so it is pre-seeded and
# left alone while the browser runs.
#
# uBlock comes from the Home Manager extension set for this profile; the
# install-level uBlock admin settings and filter lists live in
# modules/home/gui/browsers/zen.nix and apply to every profile of this Zen
# installation, including the Cinejoy window.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  port = inputs.self.lib.homelabPorts.mediaKiosk;
  kioskUrl = "http://127.0.0.1:${toString port}/";
  zen = config.programs.zen-browser.package;
  ublock = pkgs.nur.repos.rycee.firefox-addons.ublock-origin;

  kioskProfile = "${config.xdg.configHome}/zen/kiosk";

  # nixpkgs' Jellyfin module has no port option and keeps upstream 8096; the
  # system module hardcodes the same constant for the preview client.
  jellyfinPort = 8096;

  # The kiosk profile is persisted, and the switch that installs its
  # persistence mount starts the mount after Home Manager has written the
  # declarative profile, which hides user.js, the chrome CSS and the uBlock XPI
  # behind an empty directory. The seed fills the missing entries from the Home
  # Manager store paths before every browser start so a deploy (or a boot)
  # always has the same profile. Firefox keeps cookies, logins and storage in
  # the mounted directory untouched.
  seedProfile = pkgs.callPackage ./media-kiosk-seed.nix {
    userJs = config.home.file."${kioskProfile}/user.js".source;
    userChrome = config.home.file."${kioskProfile}/chrome/userChrome.css".source;
    extensions = config.home.file."${kioskProfile}/extensions".source;
  };

  # Jellyfin keeps its web session in localStorage and has no cookie or URL
  # login. This writes the record a manual login stores, using the credentials
  # the system module renders into the sops environment file, so a wiped
  # profile or a rotated password heals on the next browser start.
  jellyfinSession = pkgs.writeShellApplication {
    name = "media-kiosk-jellyfin-session";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec python3 ${./media-kiosk-jellyfin-session.py} ${lib.escapeShellArg "http://127.0.0.1:${toString jellyfinPort}"} /run/secrets/media-kiosk/env
    '';
  };
in {
  assertions = [
    {
      assertion = config.programs.zen-browser.enable;
      message = "modules.home.gui.media-kiosk uses the Home-Manager-wrapped Zen package";
    }
  ];

  programs.zen-browser.profiles."kiosk" = {
    # The default profile stays the sync/essentials profile; the kiosk is a
    # separate profile with its own ID so the Firefox module's uniqueness
    # assertions hold.
    id = 1;
    isDefault = false;
    extensions.packages = [ublock];

    # A kiosk is not a privacy browser: resistFingerprinting letterboxes the
    # viewport (black bars on the projector) and breaks media layouts, and
    # loopback HTTP would be upgraded by HTTPS-Only mode. Autoplay is allowed
    # because Jellyfin's next-episode flow expects it.
    settings = {
      "browser.startup.homepage" = kioskUrl;
      "browser.startup.page" = 1;
      "browser.aboutwelcome.enabled" = false;
      "browser.shell.checkDefaultBrowser" = false;
      "browser.sessionstore.resume_from_crash" = false;
      "browser.sessionstore.max_resumed_crashes" = 0;
      "browser.tabs.warnOnClose" = false;
      "browser.link.open_newwindow" = 2;
      "browser.link.open_newwindow.restriction" = 0;
      "browser.uidensity" = 1;
      "browser.fullscreen.autohide" = true;
      "startup.homepage_welcome_url" = "";
      "startup.homepage_welcome_url.additional" = "";
      "zen.welcome.enabled" = false;
      "zen.onboarding.enabled" = false;
      "privacy.resistFingerprinting" = false;
      "privacy.resistFingerprinting.letterboxing" = false;
      "dom.security.https_only_mode" = false;
      "media.autoplay.default" = 0;
      "media.autoplay.blocking_policy" = 0;
      "media.hardware-video-decoding.enabled" = true;
      "full-screen-api.warning.timeout" = 0;
      "full-screen-api.transition-duration.enter" = "0 0";
      "full-screen-api.transition-duration.leave" = "0 0";
      "ui.systemUsesDarkTheme" = 1;
      "layout.css.prefers-color-scheme.content-override" = 0;
      "gfx.webrender.all" = true;
      "widget.dmabuf.force-enabled" = true;
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      # uBlock ships as an XPI in the profile's extensions directory, which
      # Firefox installs disabled unless the profile opts out of the sideload
      # auto-disable scopes. Kiosk mode has no add-on manager to approve it.
      # A profile that already recorded the disabled state keeps it across
      # rescans, so extensions.json and addonStartup.json.lz4 have to be
      # dropped once for the pref to take effect.
      "extensions.autoDisableScopes" = 0;
    };

    # --new-window must produce a chromeless top-level window for Cinejoy,
    # which refuses iframes. Kiosk mode already hides the chrome for the shell;
    # this CSS covers the app windows opened by kiosk-open.
    userChrome = ''
      #navigator-toolbox {
        display: none !important;
      }
    '';
  };

  # Opens a service in a new window of the kiosk profile. The system API calls
  # this by absolute path (kiosk-open); -P keeps the profile, --new-window
  # talks to the running kiosk instance instead of starting a second one.
  home.file.".local/bin/kiosk-open" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec ${zen}/bin/zen-beta -P kiosk --new-window "$1"
    '';
  };

  # niri-session.target guarantees WAYLAND_DISPLAY, exactly like the uxplay
  # service. The browser is not restarted on deploy (Home Manager only reloads
  # units); a comin switch therefore leaves a running kiosk untouched. The two
  # pre-start steps seed the profile and refresh the Jellyfin web session
  # before Zen opens the profile.
  systemd.user.services.media-kiosk-browser = {
    Unit = {
      Description = "Projector media kiosk browser (Zen)";
      After = ["niri-session.target" "media-kiosk-api.service"];
      Wants = ["media-kiosk-api.service"];
      PartOf = ["niri-session.target"];
      BindsTo = ["niri-session.target"];
      # RestartSec=3 spaces restarts outside systemd's default 10s window, so
      # a failing ExecStartPre restarts forever; cap the loop instead and leave
      # the unit failed until an explicit reset-failed.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStartPre = [
        (lib.getExe seedProfile)
        (lib.getExe jellyfinSession)
      ];
      ExecStart = "${zen}/bin/zen-beta -P kiosk --kiosk ${kioskUrl}";
      Environment = ["MOZ_ENABLE_WAYLAND=1"];
      # /api/exit stops this unit explicitly; on-failure keeps a crash
      # recoverable without fighting a deliberate exit.
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 10;
    };
    Install.WantedBy = ["niri-session.target"];
  };
}
