{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    zellijPlugins = pkgs.callPackage ../pkgs/zellij-plugins {};

    # Bookmark slug derivation used by jjpush.
    jj-slug = pkgs.callPackage ../pkgs/jj-slug {};

    # jj workspace workflow commands, split out of the home-manager module so
    # each tool is a reviewable derivation. ocws/jjpush depend on jj-slug.
    jjTools = pkgs.callPackage ../pkgs/jj-tools {inherit jj-slug;};

    makeISO = modules:
      (inputs.nixpkgs.lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        specialArgs = {
          inherit inputs;
          repoConfig = import ../config.nix;
        };
        inherit modules;
      }).config.system.build.isoImage;

    # Every tests-vm/default.nix entry becomes packages.test-<name>, making that
    # attrset the only registry a new test needs an entry in. Tests build from
    # the flake's pkgs plus the Go alias correction the host overlay set also
    # applies (lib/build-go125-alias.nix), so a test importing sops-nix resolves
    # the removed buildGo125Module exactly as production does.
    vmTests = import ../tests-vm {
      pkgs = pkgs.appendOverlays [(import ../lib/build-go125-alias.nix)];
      inherit inputs;
      inherit (inputs) self;
    };
  in {
    # Expose nixpkgs for easier local builds (e.g., nix build .#fishPlugins.autopair)
    legacyPackages = pkgs;

    packages =
      {
        jj-lsp = pkgs.callPackage ../pkgs/jj-lsp {};

        # Instant AI Git Commit message generator (from nixpkgs)
        inherit (pkgs) lumen;

        # SSH connection manager
        dssh = pkgs.callPackage ../pkgs/dssh {};

        # Bookmark slug derivation used by jjpush
        inherit jj-slug;

        # jj workspace workflow commands (jj-tidy, jjwork, jjpush, jjtest, ocws)
        inherit (jjTools) jj-tidy jjwork jjpush jjtest ocws;

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
        };

        # Intel LMS FHS env for the m920q AMT stack (also callPackage'd in
        # hosts/m920q, this export keeps the derivation under flake eval)
        intel-lms = pkgs.callPackage ../pkgs/intel-lms {};

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
      }
      // builtins.listToAttrs (map (name: {
        name = "test-${name}";
        value = vmTests.${name};
      }) (builtins.attrNames vmTests));
  };
}
