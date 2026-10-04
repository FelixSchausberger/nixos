{
  inputs,
  lib,
  pkgs,
  ...
}: let
  browserCommon = import ./firefox-common.nix {inherit lib pkgs;};
in {
  imports = [
    inputs.zen-browser.homeModules.beta # More stable, less frequent updates
    # inputs.zen-browser.homeModules.twilight-official # Experimental build with direct official artifacts
  ];

  stylix.targets.zen-browser.profileNames = ["default"];

  programs.zen-browser = {
    enable = true;
    inherit (browserCommon) languagePacks;

    # Firefox/Zen policies - control browser behavior at the organization level
    policies =
      browserCommon.commonPolicies
      // {
        # uBlock Origin settings
        "3rdparty".Extensions = {
          "uBlock0@raymondhill.net".adminSettings = {
            userSettings = browserCommon.ublockSettings;
            selectedFilterLists = browserCommon.ublockFilters;
          };
        };
      };

    # Browser profile configuration
    profiles."default" = {
      # Declarative essentials strip. pinsForce + demote: exactly this list is
      # enforced, any hand-pinned tabs survive as normal tabs (recoverable).
      # Requires Zen to be closed during home-manager activation (the
      # activation script edits zen-sessions.jsonlz4).
      pinsForce = true;
      pinsForceAction = "demote";
      pins = {
        "Homepage" = {
          id = "44fb61d1-762c-4b90-84e9-90528be22fb4";
          url = "https://m920q.tailf2f0ca.ts.net:8445/#tools";
          position = 101;
          isEssential = true;
        };
        "Reddit" = {
          id = "712f88b3-d6cc-44ca-8292-54155db05112";
          url = "https://www.reddit.com";
          position = 102;
          isEssential = true;
        };
        "GitHub" = {
          id = "5ba46110-a91f-470d-8e69-93b76789c71a";
          url = "https://github.com";
          position = 103;
          isEssential = true;
        };
        "Gmail" = {
          id = "dcb369c7-7d73-4dd0-ba45-650e028feb9a";
          url = "https://mail.google.com";
          position = 104;
          isEssential = true;
        };
        "Proton" = {
          id = "e0b7e03c-f308-4fe9-a281-7fda94eb33ba";
          url = "https://mail.proton.me";
          position = 105;
          isEssential = true;
        };
        "WhatsApp" = {
          id = "6efb4c11-5dfe-4482-a2e6-f6f22fab27cd";
          url = "https://web.whatsapp.com";
          position = 106;
          isEssential = true;
        };
        "YouTube" = {
          id = "8fbd8fb2-d72e-46a7-9926-5142a0c580e6";
          url = "https://www.youtube.com/feed/subscriptions";
          position = 107;
          isEssential = true;
        };
        "willhaben" = {
          id = "c39d0d0d-86db-49a3-b47a-667f056e7212";
          url = "https://www.willhaben.at";
          position = 108;
          isEssential = true;
        };
        "Telegram" = {
          id = "6214ea82-d28e-4189-8b16-f849cb59f359";
          url = "https://web.telegram.org";
          position = 109;
          isEssential = true;
        };
        "keybr" = {
          id = "f643fce1-70b1-4875-b4e7-db18207935d7";
          url = "https://keybr.com";
          position = 110;
          isEssential = true;
        };
      };

      # Search engine configuration
      search =
        browserCommon.searchConfig
        // {
          engines = browserCommon.searchEngines;
        };

      extensions.packages = browserCommon.extensions;

      # Containers and spaces are managed manually by the user in the browser
      # Declarative configuration removed to preserve user customizations

      # Custom CSS overrides (Arc-2.0 theme removed due to unavailable repository)
      userChrome = ''
        /* Hide new tab button in vertical sidebar */
        #new-tab-button,
        #tabs-newtab-button,
        .zen-sidebar-action-button[data-action="new-tab"] {
          display: none !important;
        }
      '';

      # Browser settings
      settings =
        browserCommon.commonSettings
        // {
          # Zen-specific settings
          "zen.urlbar.onlyfloatingbar" = true; # Always use floating URL bar
          "zen.containers.enable_container_essentials" = true; # Enable container-specific essentials
          "zen.widget.windows.acrylic" = false; # Disable acrylic effect
          "browser.tabs.newtabbutton" = false; # Don't show new tab button in tab bar
          "extensions.bitwarden.alwaysShowPanel" = true; # Always show Bitwarden for filling

          # Additional Zen workspace and essentials settings
          "zen.workspaces.container-specific-essentials-enabled" = true; # Enable container-specific essentials in workspaces
          "zen.workspaces.force-container-workspace" = true; # Force containers to create workspaces
          "zen.pinned-tab-manager.restore-pinned-tabs-to-pinned-url" = true; # Restore pinned tabs properly

          # Linux transparency settings (GNOME/Wayland compatible)
          "zen.widget.linux.transparency" = true; # Enable Linux-specific transparency

          # Skip first-time setup and onboarding
          "browser.aboutwelcome.enabled" = false; # Disable welcome screen
          "zen.welcome.enabled" = false; # Disable Zen welcome screen
          "zen.onboarding.enabled" = false; # Disable Zen onboarding
          "startup.homepage_welcome_url" = ""; # Disable welcome homepage
          "startup.homepage_welcome_url.additional" = ""; # Disable additional welcome pages
        };
    };
  };

  # Set as default browser for various MIME types
  xdg = {
    enable = true;
    mimeApps = let
      associations = let
        zenDesktop = "zen.desktop";
        mimeTypes = [
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
        ];
      in
        builtins.listToAttrs (map (name: {
            inherit name;
            value = zenDesktop;
          })
          mimeTypes);
    in {
      associations.added = associations;
      defaultApplications = associations;
    };
  };
}
