{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1; // Enable Wayland support
  };

  programs.zen-browser = {
    enable = true;
    languagePacks = ["de" "en-US"]; // Language packs for German and English

    // Firefox/Zen policies - control browser behavior at the organization level
    policies = {
      // Disable various telemetry and unwanted features
      DisableAppUpdate = true; // Don't check for updates (managed by Nix)
      DisableFeedbackCommands = true; // Remove feedback options
      DisableFirefoxStudies = true; // Disable participation in Firefox studies
      DisablePocket = true; // Disable Pocket integration
      DisableTelemetry = true; // Disable telemetry collection
      DontCheckDefaultBrowser = true; // Don't check if browser is default
      NoDefaultBookmarks = true; // Don't create default bookmarks
      OfferToSaveLogins = false; // Don't offer to save passwords
      PasswordManagerEnabled = false; // Disable the built-in password manager

      // Configure Firefox home page
      FirefoxHome = {
        Search = false; // Disable search box
        TopSites = false; // Disable top sites
        SponsoredTopSites = false; // Disable sponsored sites
        Highlights = false; // Disable highlights
        Pocket = false; // Disable pocket
        SponsoredPocket = false; // Disable sponsored pocket content
        Snippets = false; // Disable snippets
        Locked = false; // Don't lock these settings
      };

      // Configure start page
      Homepage = {
        StartPage = "none"; // Don't show a start page
      };

      // Disable first run and post-update pages
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";

      // uBlock Origin settings
      "3rdparty".Extensions = {
        "uBlock0@raymondhill.net".adminSettings = {
          userSettings = rec {
            uiTheme = "dark"; // Dark theme for uBlock
            uiAccentCustom = true;
            uiAccentCustom0 = "#8300ff"; // Custom accent color
            cloudStorageEnabled = false; // Disable cloud storage
            importedLists = [
              "https://filters.adtidy.org/extension/ublock/filters/3.txt"
              "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
            ];
            externalLists = lib.concatStringsSep "\n" importedLists;
          };
          selectedFilterLists = [
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
            // YouTube cleanup filters
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
        };
      };
    };

    // Browser profile configuration
    profiles."default" = {
      // Search engine configuration
      search = {
        default = "ddg"; // Set DuckDuckGo as default
        force = true; // Force this search engine
        engines = {
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
            updateInterval = 24 * 60 * 60 * 1000; // Update once per day
            definedAliases = ["@nw"];
          };

          "github" = {
            urls = [{template = "https://github.com/search?q={searchTerms}&type=repositories";}];
            icon = "https://github.com/favicon.ico";
            definedAliases = ["@gh"];
          };

          "home manager" = {
            urls = [{template = "https://mipmip.github.io/home-manager-option-search/?query={searchTerms}";}];
            icon = "https://nixos.org/favicon.ico";
            definedAliases = ["@hm"];
          };

          "youtube" = {
            urls = [{template = "https://www.youtube.com/results?search_query={searchTerms}";}];
            icon = "https://www.youtube.com/favicon.ico";
            definedAliases = ["@yt"];
          };

          // Hide default search engines we don't want
          "amazon".metaData.hidden = true;
          "bing".metaData.hidden = true;
          "ebay".metaData.hidden = true;
          "wikipedia".metaData.hidden = true;
        };
      };

      // Extensions configuration
      extensions = {
        // Use the same Firefox extension system
        packages = with pkgs.nur.repos.rycee.firefox-addons; [
          bitwarden           // Password manager
          darkreader          // Dark mode for websites
          ff2mpv              // Open videos in mpv
          i-dont-care-about-cookies // Remove cookie warnings
          keepa               // Price history charts
          tabliss             // Custom new tab page
          ublock-origin       // Ad blocker
          unpaywall           // Access research papers
          vimium-c            // Vim-like keyboard navigation
          youtube-nonstop     // Prevent YouTube auto-pause
        ];
      };

      // Browser settings
      settings = {
        // Privacy settings
        "app.normandy.first_run" = false;               // Disable Normandy/Shield telemetry system
        "app.shield.optoutstudies.enabled" = false;     // Opt out of shield studies
        "app.update.channel" = "default";               // Use default update channel

        // General behavior settings
        "browser.aboutConfig.showWarning" = false;      // Don't warn when opening about:config
        "browser.contentblocking.category" = "strict";  // Use strict content blocking
        "browser.ctrlTab.recentlyUsedOrder" = false;    // Switch tabs in order, not by recency
        "browser.discovery.enabled" = false;            // Disable discovery pane
        
        // New tab page settings
        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        
        // Browser startup settings
        "browser.shell.checkDefaultBrowser" = false;    // Don't check if default browser

        // Interface settings
        "browser.toolbars.bookmarks.visibility" = "never"; // Hide bookmarks toolbar
        
        // URL bar settings
        "browser.urlbar.quickactions.enabled" = false;  // Disable URL bar quick actions
        "browser.urlbar.suggest.openpage" = false;      // Don't suggest open pages
        
        // Privacy and security settings
        "datareporting.policy.dataSubmissionEnable" = false; // Disable data submission
        "dom.security.https_only_mode" = true;          // Use HTTPS only mode
        "dom.security.https_only_mode_ever_enabled" = true;
        "privacy.donottrackheader.enabled" = true;      // Enable Do Not Track
        "privacy.trackingprotection.enabled" = true;    // Enable tracking protection
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.webrtc.legacyGlobalIndicator" = false; // Disable WebRTC sharing indicator
        
        // Extensions settings
        "extensions.pocket.enabled" = false;            // Disable Pocket
        
        // Hardware acceleration
        "gfx.webrender.all" = true;                     // Force GPU acceleration
        "media.ffmpeg.vaapi.enabled" = true;            // Enable VA-API acceleration
        "widget.dmabuf.force-enabled" = true;           // Enable dmabuf (required for Wayland)
        
        // Reader mode
        "reader.parse-on-load.force-enabled" = true;    // Force enable reader mode
        
        // User customization
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true; // Enable userChrome.css
      };
    };
  };

  // Persist Mozilla data between boots
  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".mozilla";
      }
      {
        directory = ".zen";
      }
    ];
  };

  // Set as default browser for various MIME types
  xdg = {
    enable = true;
    mimeApps = let
      associations = builtins.listToAttrs (map (name: {
          inherit name;
          value = let
            zen-browser = inputs.zen-browser.packages.${pkgs.system}.twilight;
          in
            zen-browser.meta.desktopFile;
        }) [
          "x-scheme-handler/https"
          "x-scheme-handler/http"
          "text/html"
          "application/xhtml+xml"
          "application/x-extension-html"
          "application/x-extension-htm"
          "application/x-extension-shtml"
          "application/x-extension-xhtml"
          "application/x-extension-xht"
          "application/json"
          "text/plain"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
          "x-scheme-handler/mailto"
          "image/*"
        ]);
    in {
      associations.added = associations;
      defaultApplications = associations;
    };
  };
}
