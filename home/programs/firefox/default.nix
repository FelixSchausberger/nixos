{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkForce;
in {
  imports = [
    inputs.nur.nixosModules.nur
  ];

  # home.file = {
  #   ".mozilla/firefox/default/chrome/theme" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/theme";
  #     recursive = true;
  #   };
  #   ".mozilla/firefox/default/chrome/userChrome.css" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/userChrome.css";
  #   };
  #   ".mozilla/firefox/default/chrome/userContent.css" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/userContent.css";
  #   };
  #   ".mozilla/firefox/default/user.js" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/user.js";
  #   };
  # };

  programs.firefox = {
    enable = true;
    package = inputs.firefox-nightly.packages.${pkgs.system}.firefox-nightly-bin;
    languagePacks = ["de" "en-US"];

    /*
    ---- POLICIES ----
    */
    # Check about:policies#documentation for options.
    policies = {
      "3rdparty".Extensions = {
        # https://github.com/gorhill/uBlock/blob/master/platform/common/managed_storage.json
        "uBlock0@raymondhill.net".adminSettings = {
          userSettings = rec {
            uiTheme = "dark";
            uiAccentCustom = true;
            uiAccentCustom0 = "#8300ff";
            cloudStorageEnabled = mkForce false; # Security liability?
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
          ];
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

      PasswordManagerEnabled = false;
    };

    profiles."default" = {
      search = {
        default = "DuckDuckGo";
        force = true;
        engines = {
          "Nix Options" = {
            urls = [{template = "https://search.nixos.org/options?type=options&query={searchTerms}";}];
            iconURL = "https://nixos.org/favicon.ico";
            definedAliases = ["@no"];
          };

          "Nix Packages" = {
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

          "NixOS Wiki" = {
            urls = [{template = "https://nixos.wiki/index.php?search={searchTerms}";}];
            iconUpdateURL = "https://nixos.wiki/favicon.png";
            updateInterval = 24 * 60 * 60 * 1000; # every day
            definedAliases = ["@nw"];
          };

          "GitHub" = {
            urls = [{template = "https://github.com/search?q={searchTerms}&type=repositories";}];
            iconURL = "https://github.com/favicon.ico";
            definedAliases = ["@gh"];
          };

          "Home Manager" = {
            urls = [{template = "https://mipmip.github.io/home-manager-option-search/?query={searchTerms}";}];
            iconURL = "https://nixos.org/favicon.ico";
            definedAliases = ["@hm"];
          };

          "YouTube" = {
            urls = [{template = "https://www.youtube.com/results?search_query={searchTerms}";}];
            iconURL = "https://www.youtube.com/favicon.ico";
            definedAliases = ["@yt"];
          };

          # Disable default search engines
          "Amazon.de".metaData.hidden = true;
          "Bing".metaData.hidden = true;
          # "DuckDuckGo".metaData.hidden = true;
          "eBay".metaData.hidden = true;
          "Wikipedia (en)".metaData.hidden = true;
        };
      };

      # https://nur.nix-community.org/repos/rycee/
      extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        bitwarden # At home, at work, or on the go, Bitwarden easily secures all your passwords, passkeys, and sensitive information.
        darkreader # Dark mode for every website. Take care of your eyes, use dark theme for night and daily browsing.
        ff2mpv # Tries to play links in mpv.
        i-dont-care-about-cookies #  	Get rid of cookie warnings from almost all websites!
        keepa # → Price History charts → Price Drop & Availability Alerts→ Over 1 billion tracked products→ Supports Amazon.com
        privacy-badger # Automatically learns to block invisible trackers.
        tabliss # A beautiful New Tab page with many customisable backgrounds and widgets that does not require any permissions.
        to-deepl # Right-click on a section of text and click on “To DeepL” to translate it to your language. Default language is selected in extension preferences.
        # tridactyl # Vim, but in your browser.
        ublock-origin # Finally, an efficient wide-spectrum content blocker. Easy on CPU and memory.
        unpaywall # Get free text of research papers as you browse, using Unpaywall’s index of ten million legal, open-access articles.
        vimium # The Hacker’s Browser.
        youtube-nonstop # Tired of getting that “Video paused. Continue watching?” confirmation dialog?
      ];

      # https://github.com/gvolpe/nix-config/blob/6feb7e4f47e74a8e3befd2efb423d9232f522ccd/home/programs/browsers/firefox.nix
      settings = {
        # disable Studies
        # disable Normandy/Shield [FF60+]
        # Shield is a telemetry system that can push and test "recipes"
        "app.normandy.first_run" = false;
        "app.shield.optoutstudies.enabled" = false;

        # Disable updates (pretty pointless with nix)
        "app.update.channel" = "default";

        "browser.aboutConfig.showWarning" = false;
        "browser.bookmarks.restore_default_bookmarks" = false;
        "browser.contentblocking.category" = "strict";
        "browser.ctrlTab.recentlyUsedOrder" = false;
        "browser.discovery.enabled" = false;
        "browser.laterrun.enabled" = false;

        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" =
          false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" =
          false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "";
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";
        "browser.newtabpage.activity-stream.section.highlights.includePocket" =
          false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.pinned" = false;

        "browser.search.region" = "DE";
        "browser.search.widget.inNavBar" = true;

        "browser.protections_panel.infoMessage.seen" = true;
        "browser.quitShortcut.disabled" = true;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.ssb.enabled" = true;

        "browser.startup.homepage.StartPage" = "none";
        "browser.startup.page.StartPage" = "none";

        "browser.tabs.allow_transparent_browser" = true;
        "browser.toolbars.bookmarks.visibility" = "never";

        # Disable all the annoying quick actions
        "browser.urlbar.hidebuttons" = true;
        "browser.urlbar.placeholderName" = "DuckDuckGo";
        "browser.urlbar.quickactions.enabled" = false;
        "browser.urlbar.quickactions.showPrefs" = false;
        "browser.urlbar.shortcuts.quickactions" = false;
        "browser.urlbar.suggest.quickactions" = false;
        "browser.urlbar.suggest.openpage" = false;

        "datareporting.policy.dataSubmissionEnable" = false;
        "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;

        "doh-rollout.doneFirstRun" = true;

        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_ever_enabled" = true;

        # Auto enable extensions
        "extensions.autoDisableScopes" = 0;
        "extensions.getAddons.showPane" = false;
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "extensions.pocket.enabled" = false;

        "gfx.webrender.all" = true; # Force enable GPU acceleration

        "identity.fxaccounts.enabled" = false;

        "media.ffmpeg.vaapi.enabled" = true;

        "pref.privacy.disable_button.view_passwords" = false;

        "print.print_footerleft" = "";
        "print.print_footerright" = "";
        "print.print_headerleft" = "";
        "print.print_headerright" = "";

        "privacy.donottrackheader.enabled" = true;

        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        # Hide the "sharing indicator", it's especially annoying
        # with tiling WMs on wayland
        "privacy.webrtc.legacyGlobalIndicator" = false;

        # Keep the reader button enabled at all times; really don't
        # care if it doesn't work 20% of the time, most websites are
        # crap and unreadable without this
        "reader.parse-on-load.force-enabled" = true;

        "signon.rememberSignons" = false;

        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        "ui.key.menuAccessKeyFocuses" = false;

        "widget.dmabuf.force-enabled" = true; # Required in recent Firefoxes
      };

      userChrome = ''
        /* Disable back, forward and close button */
        /* #back-button, */
        #forward-button { display:none!important; }

        .titlebar-buttonbox-container{ display:none }

        /* Hide tab close buttons */
        .tabbrowser-tab .tab-close-button {
          visibility: collapse !important;
        }

        /* Hide extensions button */
        #unified-extensions-button, #unified-extensions-button > .toolbarbutton-icon{
          width: 0px !important;
          padding: 0px !important;
        }

        /* Hide bookmark star button */
        #star-button-box {display: none !important;}

        /* Disable site information button */
        #identity-box {display: none !important;}

        /* Disable enhanced tracking protection button */
        #tracking-protection-icon-container {display: none;}
      '';
    };
  };
}
