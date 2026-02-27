{
  inputs,
  lib,
  pkgs,
  ...
}: let
  browserCommon = import ./firefox-common.nix {
    inherit lib pkgs;
    firefox-addons = inputs.firefox-addons or null;
  };
in {
  imports = [
    inputs.zen-browser.homeModules.beta # More stable, less frequent updates
    # inputs.zen-browser.homeModules.twilight-official # Experimental build with direct official artifacts
  ];

  stylix.targets.zen-browser.profileNames = ["default"];

  programs.zen-browser = {
    enable = true;
    suppressXdgMigrationWarning = true;
    inherit (browserCommon) languagePacks nativeMessagingHosts;

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
      # Search engine configuration
      search =
        browserCommon.searchConfig
        // {
          engines = browserCommon.searchEngines;
        };

      # Extensions configuration - use flake source for compatibility
      extensions = {
        packages = browserCommon.getExtensions "flake";
      };

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
          "browser.tabs.allow_transparent_browser" = true; # Allow browser transparency
          "zen.widget.linux.transparency" = true; # Enable Linux-specific transparency
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # Enable userChrome.css

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
