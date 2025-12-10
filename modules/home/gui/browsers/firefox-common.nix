{
  lib,
  pkgs,
  ...
}: {
  # Shared browser configuration for Firefox and Zen
  # Contains common settings, extensions, and search engines

  # Common language packs
  languagePacks = ["de" "en-US"];

  # Common native messaging hosts
  nativeMessagingHosts = [pkgs.firefoxpwa];

  # Common search configuration
  searchConfig = {
    default = "ddg"; # Set DuckDuckGo as default
    force = true; # Force this search engine
    privateDefault = "ddg"; # Use same search engine in private windows
  };

  # Common search engines
  searchEngines = {
    "nix options" = {
      urls = [{template = "https://search.nixos.org/options?type=options&query={searchTerms}";}];
      icon = "https://nixos.org/favicon.ico";
      definedAliases = ["@no"];
    };

    "nix packages" = {
      urls = [
        {
          template = "https://search.nixos.org/packages";
          params = [
            {
              name = "type";
              value = "packages";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      definedAliases = ["@np"];
    };

    "nixos wiki" = {
      urls = [{template = "https://nixos.wiki/index.php?search={searchTerms}";}];
      icon = "https://nixos.wiki/favicon.png";
      updateInterval = 24 * 60 * 60 * 1000;
      definedAliases = ["@nw"];
    };

    "noogle" = {
      urls = [{template = "https://noogle.dev/q?term={searchTerms}";}];
      icon = "https://noogle.dev/favicon.png";
      definedAliases = ["@ng"];
    };

    "github repos" = {
      urls = [{template = "https://github.com/search?q={searchTerms}&type=repositories";}];
      icon = "https://github.com/favicon.ico";
      definedAliases = ["@gh"];
    };

    "github nix" = {
      urls = [{template = "https://github.com/search?q=lang%3Anix+{searchTerms}&type=code";}];
      icon = "https://github.com/favicon.ico";
      definedAliases = ["@ghn"];
    };

    "home manager" = {
      urls = [{template = "https://home-manager-options.extranix.com/?query={searchTerms}&release=master";}];
      icon = "https://nixos.org/favicon.ico";
      definedAliases = ["@hm"];
    };

    "youtube" = {
      urls = [{template = "https://www.youtube.com/results?search_query={searchTerms}";}];
      icon = "https://www.youtube.com/favicon.ico";
      definedAliases = ["@yt"];
    };

    # Hide unwanted search engines
    "amazon".metaData.hidden = true;
    "bing".metaData.hidden = true;
    "ebay".metaData.hidden = true;
    "wikipedia".metaData.hidden = true;
    "ecosia".metaData.hidden = true;
  };

  # Common extensions
  extensions = with pkgs.nur.repos.rycee.firefox-addons; [
    bitwarden
    darkreader
    ff2mpv
    i-dont-care-about-cookies
    keepa
    ublock-origin
    vimium-c
    youtube-nonstop
  ];

  # Common uBlock Origin configuration
  ublockSettings = rec {
    uiTheme = "dark";
    uiAccentCustom = true;
    uiAccentCustom0 = "#8300ff";
    cloudStorageEnabled = false; # Security liability - disable cloud sync
    allowPrivateBrowsing = true; # Allow uBlock to run in private windows
    importedLists = [
      "https://filters.adtidy.org/extension/ublock/filters/3.txt"
      "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
    ];
    externalLists = lib.concatStringsSep "\n" importedLists;
  };

  ublockFilters = [
    "CZE-0"
    "adguard-generic"
    "adguard-annoyance"
    "adguard-social"
    "adguard-spyware-url"
    "easylist"
    "easyprivacy"
    "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
    "plowe-0"
    "ublock-abuse"
    "ublock-badware"
    "ublock-filters"
    "ublock-privacy"
    "ublock-quick-fixes"
    "ublock-unbreak"
    "urlhaus-1"
    # YouTube cleanup filters
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/For you/i))"
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/People also watched/i))"
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/People also search for/i))"
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/Previously watched/i))"
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/Explore more/i))"
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/Related to your search/i))"
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/From related searches/i))"
    "www.youtube.com##ytd-shelf-renderer.style-scope:has(span:has-text(/Channels new to you/i))"
    "www.youtube.com##ytd-horizontal-card-list-renderer.ytd-item-section-renderer.style-scope"
    "www.youtube.com##ytd-reel-shelf-renderer.ytd-item-section-renderer.style-scope"
  ];

  # Common policies
  commonPolicies = {
    DisableAppUpdate = true;
    DisableFeedbackCommands = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DisableTelemetry = true;
    DontCheckDefaultBrowser = true;
    NoDefaultBookmarks = true;
    OfferToSaveLogins = false;
    PasswordManagerEnabled = false;

    # Extension settings
    ExtensionSettings = {
      # Pin Bitwarden extension to toolbar
      "446900e4-71c2-419f-a6a7-df9c091e268b" = {
        default_area = "navbar";
      };
    };

    FirefoxHome = {
      Search = false;
      TopSites = false;
      SponsoredTopSites = false;
      Highlights = false;
      Pocket = false;
      SponsoredPocket = false;
      Snippets = false;
      Locked = false;
    };

    Homepage = {
      StartPage = "none";
    };

    OverrideFirstRunPage = "";
    OverridePostUpdatePage = "";
  };

  # Common browser settings
  commonSettings = {
    # Privacy settings
    "app.normandy.first_run" = false;
    "app.shield.optoutstudies.enabled" = false;
    "app.update.channel" = "default";

    # General behavior
    "browser.aboutConfig.showWarning" = false;
    "browser.contentblocking.category" = "strict";
    "browser.ctrlTab.recentlyUsedOrder" = false;
    "browser.discovery.enabled" = false;

    # New tab page
    "browser.newtabpage.activity-stream.showSearch" = false;
    "browser.newtabpage.activity-stream.feeds.snippets" = false;
    "browser.newtabpage.activity-stream.showSponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

    # Browser behavior
    "browser.shell.checkDefaultBrowser" = false;
    "browser.tabs.allow_transparent_browser" = true;
    "browser.tabs.hoverPreview.enabled" = true;
    "browser.sessionstore.restore_pinned_tabs_on_demand" = true;
    "browser.toolbars.bookmarks.visibility" = "never";

    # Dark theme
    "ui.systemUsesDarkTheme" = 1;
    "layout.css.prefers-color-scheme.content-override" = 0;

    # URL bar
    "browser.urlbar.quickactions.enabled" = false;
    "browser.urlbar.suggest.openpage" = false;
    "browser.urlbar.openintab" = true;

    # Privacy and security
    "datareporting.policy.dataSubmissionEnable" = false;
    "datareporting.healthreport.uploadEnabled" = false;
    "toolkit.telemetry.enabled" = false;
    "toolkit.telemetry.unified" = false;
    "toolkit.telemetry.archive.enabled" = false;
    "toolkit.telemetry.newProfilePing.enabled" = false;
    "toolkit.telemetry.shutdownPingSender.enabled" = false;
    "toolkit.telemetry.updatePing.enabled" = false;
    "toolkit.telemetry.bhrPing.enabled" = false;
    "toolkit.telemetry.firstShutdownPing.enabled" = false;
    "toolkit.coverage.opt-out" = true;
    "toolkit.coverage.endpoint.base" = "";
    "browser.ping-centre.telemetry" = false;
    "browser.newtabpage.activity-stream.feeds.telemetry" = false;
    "browser.newtabpage.activity-stream.telemetry" = false;

    # HTTPS-Only Mode
    "dom.security.https_only_mode" = true;
    "dom.security.https_only_mode_ever_enabled" = true;
    "dom.security.https_only_mode_send_http_background_request" = false;

    # Tracking Protection
    "privacy.donottrackheader.enabled" = true;
    "privacy.trackingprotection.enabled" = true;
    "privacy.trackingprotection.pbmode.enabled" = true;
    "privacy.trackingprotection.socialtracking.enabled" = true;
    "privacy.trackingprotection.cryptomining.enabled" = true;
    "privacy.trackingprotection.fingerprinting.enabled" = true;

    # Cookie behavior (0 = Accept all, 1 = Block third-party, 2 = Block all, 4 = Block known trackers)
    "network.cookie.cookieBehavior" = 4;
    "network.cookie.lifetimePolicy" = 2; # Accept for session only

    # Disable WebRTC leaks
    "media.peerconnection.enabled" = false;
    "media.peerconnection.ice.default_address_only" = true;
    "media.peerconnection.ice.no_host" = true;
    "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;
    "privacy.webrtc.legacyGlobalIndicator" = false;

    # Search suggestions
    "browser.search.suggest.enabled" = false;
    "browser.urlbar.suggest.searches" = false;
    "browser.fixup.alternate.enabled" = false;

    # Disable prefetching
    "network.dns.disablePrefetch" = true;
    "network.prefetch-next" = false;
    "network.predictor.enabled" = false;
    "network.http.speculative-parallel-limit" = 0;

    # Disable geolocation
    "geo.enabled" = false;
    "geo.provider.network.url" = "";
    "browser.region.network.url" = "";
    "browser.region.update.enabled" = false;

    # Disable crash reports
    "breakpad.reportURL" = "";
    "browser.tabs.crashReporting.sendReport" = false;
    "browser.crashReports.unsubmittedCheck.enabled" = false;
    "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;

    # Disable beacon
    "beacon.enabled" = false;

    # Disable battery API
    "dom.battery.enabled" = false;

    # Disable network API
    "dom.network.enabled" = false;

    # Referrer policy
    "network.http.referer.XOriginPolicy" = 2; # Send only when host matches
    "network.http.referer.XOriginTrimmingPolicy" = 2; # Trim to scheme, host, port

    # Password and autofill settings
    "signon.rememberSignons" = false;
    "browser.formfill.enable" = true;
    "signon.autofillForms" = true;
    "signon.autofillForms.http" = true;
    "browser.payments.enable" = false;

    # Extensions
    "extensions.pocket.enabled" = false;

    # Hardware acceleration
    "gfx.webrender.all" = true;
    "media.ffmpeg.vaapi.enabled" = true;
    "widget.dmabuf.force-enabled" = true;

    # Reader mode
    "reader.parse-on-load.force-enabled" = true;

    # User customization
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

    # User agent override to mimic Chrome for better YouTube performance
    "general.useragent.override" = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";
  };
}
