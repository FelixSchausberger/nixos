{
  inputs,
  lib,
  pkgs,
  ...
}: let
  browserCommon = import ./firefox-common.nix {inherit lib pkgs;};
in {
  imports = [
  ];

  programs.firefox = {
    enable = true;
    package = inputs.firefox-nightly.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin;
    inherit (browserCommon) languagePacks;

    policies =
      browserCommon.commonPolicies
      // {
        "3rdparty".Extensions = {
          "uBlock0@raymondhill.net".adminSettings = {
            userSettings = browserCommon.ublockSettings;
            selectedFilterLists = browserCommon.ublockFilters;
          };
        };
      };

    profiles."default" = {
      search =
        browserCommon.searchConfig
        // {
          engines = browserCommon.searchEngines;
        };

      settings =
        browserCommon.commonSettings
        // {
          # Firefox-specific settings
          "browser.bookmarks.restore_default_bookmarks" = false;
          "browser.laterrun.enabled" = false;
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
          "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "";
          "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
          "browser.newtabpage.pinned" = false;
          "browser.search.region" = "AT";
          "browser.search.widget.inNavBar" = true;
          "browser.protections_panel.infoMessage.seen" = true;
          "browser.quitShortcut.disabled" = true;
          "browser.ssb.enabled" = true;
          "browser.startup.homepage.StartPage" = "none";
          "browser.startup.page.StartPage" = "none";
          "browser.tabs.closeWindowWithLastTab" = false;
          "browser.tabs.tabmanager.enabled" = false;
          "browser.theme.native-theme" = true;
          "browser.urlbar.hidebuttons" = true;
          "browser.urlbar.placeholderName" = "DuckDuckGo";
          "browser.urlbar.quickactions.showPrefs" = false;
          "browser.urlbar.shortcuts.quickactions" = false;
          "browser.urlbar.suggest.quickactions" = false;
          "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;
          "doh-rollout.doneFirstRun" = true;
          "extensions.autoDisableScopes" = 0;
          "extensions.getAddons.showPane" = false;
          "extensions.htmlaboutaddons.recommendations.enabled" = false;
          "identity.fxaccounts.enabled" = false;
          "pref.privacy.disable_button.view_passwords" = false;
          "print.print_footerleft" = "";
          "print.print_footerright" = "";
          "print.print_headerleft" = "";
          "print.print_headerright" = "";
          "ui.key.menuAccessKeyFocuses" = false;
          "widget.windows.mica" = true;
        };

      userChrome = ''
        /* Disable back, forward and close button */
        /* #back-button, */
        #forward-button {
          display:none!important;
        }

        .titlebar-buttonbox-container{
          display:none
        }

        /* Hide tab close buttons */
        .tabbrowser-tab .tab-close-button {
          visibility: collapse !important;
        }

        /* Disable site information button */
        #identity-box {
          display: none !important;
        }

        /* Disable enhanced tracking protection button */
        #tracking-protection-icon-container {
          display: none;
        }

        /* Center urlbar text */
        #urlbar {
          text-align: center;
        }

        /* Transparency */
        #sidebar-main, #sidebar-box {
          background-color: transparent !important;
          background-image: none !important;
        }

        #navigator-toolbox {
          background-color: transparent !important;
           border-bottom: none !important;
        }

        #main-window {
          background-color: transparent !important;
        }

        #PersonalToolbar {
          background-color: transparent !important;
        }

        #nav-bar {
          border-top: none !important;
        }

        #nav-bar{
          background-color: transparent !important;
        }

        /* Search box transparency */
        #urlbar {
          --toolbar-field-background-color:  transparent !important;
        }

        /* Fixing window control buttons */
        #navigator-toolbox .titlebar-min .toolbarbutton-icon,
        #navigator-toolbox .titlebar-restore .toolbarbutton-icon,
        #navigator-toolbox .titlebar-max .toolbarbutton-icon{
         opacity: 0;
        }

        /* Fixing window control buttons, could need a change with different resolutions or windows scaling */
        #navigator-toolbox .titlebar-buttonbox-container{
          height: 28px;
        }

        /* Fixing window control buttons, could need a change with different resolutions or windows scaling */
        :root[sizemode="maximized"] #navigator-toolbox .titlebar-close .toolbarbutton-icon{
        /*   opacity:0; */
          margin-right:2px !important;
        }

        /* Remove the white line around the content window */
        @media (-moz-bool-pref: "sidebar.revamp") {
          #tabbrowser-tabbox {
            outline: none !important;
        /*     box-shadow: none !important; */
          }
        }
      '';
    };
  };

  # home.file = {
  #   ".local/state/firefox/default/chrome/theme" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/theme";
  #     recursive = true;
  #   };
  #   ".local/state/firefox/default/chrome/userChrome.css" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/userChrome.css";
  #   };
  #   ".local/state/firefox/default/chrome/userContent.css" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/userContent.css";
  #   };
  #   ".local/state/firefox/default/user.js" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${inputs.self}/home/programs/firefox/ffultima1.9.0/user.js";
  #   };
  # };

  xdg = {
    enable = true;
    mimeApps = let
      associations = builtins.listToAttrs (map (name: {
          inherit name;
          value = ["firefox.desktop"];
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
        ]);
    in {
      associations.added = associations;
      defaultApplications = associations;
    };
  };
}
