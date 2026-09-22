{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    zellijPlugins = pkgs.callPackage ../pkgs/zellij-plugins {};
    makeISO = modules:
      (inputs.nixpkgs.lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        specialArgs = {
          inherit inputs;
          repoConfig = import ../config.nix;
        };
        inherit modules;
      }).config.system.build.isoImage;
  in {
    # Expose nixpkgs for easier local builds (e.g., nix build .#fishPlugins.autopair)
    legacyPackages = pkgs;

    packages = {
      jj-lsp = pkgs.callPackage ../pkgs/jj-lsp {};

      # Instant AI Git Commit message generator (from nixpkgs)
      inherit (pkgs) lumen;

      # SSH connection manager
      dssh = pkgs.callPackage ../pkgs/dssh {};

      # Bookmark slug derivation used by jjpush
      jj-slug = pkgs.callPackage ../pkgs/jj-slug {};

      inherit
        (zellijPlugins)
        harpoon
        zellij-forgot
        zjstatus-hints
        ;

      # Prometheus exporter for AdGuard Home
      adguard-exporter = pkgs.callPackage ../pkgs/adguard-exporter {};

      # Nextcloud calendar to Grafana annotation syncer (garmin.nix)
      garmin-calendar-sync = pkgs.callPackage ../pkgs/garmin-calendar-sync {};

      # Homelab topology diagram generator (D2 → SVG + HTML)
      homelab-topology = pkgs.callPackage ../pkgs/topology {
        m920qConfig = inputs.self.nixosConfigurations.m920q.config;
        # playwright 1.63.0's webkit build fails at auto-patchelf on channel
        # b1b875982b17 (missing libmanette for WPEWebKit), and d2 0.8.1 drops
        # the whole browser tree (webkit included) into its closure. The
        # dagre rendering of this package never uses image support, so supply
        # d2 with a chromium-only browser set instead of patching webkit.
        d2 = pkgs.d2.override {
          playwright-driver = {
            browsers = pkgs.playwright-driver.passthru.browsers-chromium;
          };
        };
      };

      # Applications
      quantumlauncher = pkgs.callPackage ../pkgs/quantumlauncher {};

      # IRIS shell autocomplete assistant
      iris = inputs.iris.packages.${pkgs.stdenv.hostPlatform.system}.iris;

      # Vitals health monitoring (from local vitals repo)
      vitals-daemon = inputs.vitals.packages.${pkgs.stdenv.hostPlatform.system}.daemon;
      vitals-cli = inputs.vitals.packages.${pkgs.stdenv.hostPlatform.system}.cli;
      vitals-tui = inputs.vitals.packages.${pkgs.stdenv.hostPlatform.system}.tui;

      # Minimal installer ISO (fast rebuilds for testing)
      installer-iso-minimal = makeISO [../hosts/installer-minimal];

      # Full installer ISO (comprehensive recovery environment)
      installer-iso-full = makeISO [../hosts/installer];

      # Portable recovery ISO (TUI-only live USB with ZFS + recovery tooling)
      installer-iso-portable = makeISO [../hosts/portable];

      # NixOS VM Integration Tests
      test-caddy-proxy =
        (import ../tests-vm {
          inherit pkgs inputs;
          inherit (inputs) self;
        }).caddy-proxy;
      test-zfs-backup =
        (import ../tests-vm {
          inherit pkgs inputs;
          inherit (inputs) self;
        }).zfs-backup;
      test-streaming-services =
        (import ../tests-vm {
          inherit pkgs inputs;
          inherit (inputs) self;
        }).streaming-services;
      test-deferred-maintenance =
        (import ../tests-vm {
          inherit pkgs inputs;
          inherit (inputs) self;
        }).deferred-maintenance;
      # VM tests build from this flake's pkgs (no host overlays applied). The
      # monitoring test imports sops-nix, so it needs the buildGo125Module
      # alias mapping (see modules/system/nixpkgs-overlays.nix).
      test-monitoring-alerting = let
        vmPkgs = pkgs.appendOverlays [
          (_final: prev: {
            buildGo125Module = prev.buildGoModule;
          })
        ];
      in
        (import ../tests-vm {
          pkgs = vmPkgs;
          inherit inputs;
          inherit (inputs) self;
        }).monitoring-alerting;
    };
  };
}
