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

      inherit
        (zellijPlugins)
        harpoon
        zellij-attention
        zellij-forgot
        zjstatus-hints
        ;

      # Prometheus exporter for AdGuard Home
      adguard-exporter = pkgs.callPackage ../pkgs/adguard-exporter {};

      # Homelab topology diagram generator (D2 → SVG + HTML)
      homelab-topology = pkgs.callPackage ../pkgs/topology {
        m920qConfig = inputs.self.nixosConfigurations.m920q.config;
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

      # NixOS VM Integration Tests
      test-m920q-mode-switch =
        (import ../tests-vm {
          inherit pkgs inputs;
          inherit (inputs) self;
        }).m920q-mode-switch;
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
    };
  };
}
