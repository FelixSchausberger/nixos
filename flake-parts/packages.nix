{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    zellijPlugins = pkgs.callPackage ../pkgs/zellij-plugins {};

    # Bookmark slug derivation used by jjpush.
    jj-slug = pkgs.callPackage ../pkgs/jj-slug {};

    # jj workspace workflow commands, split out of the home-manager module so
    # each tool is a reviewable derivation. jjpush depends on jj-slug.
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
    # attrset the only registry a new test needs an entry in.
    vmTests = import ../tests-vm {
      inherit pkgs inputs;
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

        # GrapheneOS provisioning for the Pixel 10a manifest in lib/phone.nix:
        # wraps adb/fdroidcl, renders Obtainium imports, prints the lanes
        # Android only offers interactively.
        pixel-provision = pkgs.callPackage ../pkgs/pixel-provision {};

        # Bookmark slug derivation used by jjpush
        inherit jj-slug;

        # jj workspace workflow commands (jj-tidy, jjwork, jjpush, jjtest)
        inherit (jjTools) jj-tidy jjwork jjpush jjtest;

        # Workspace seat manager, extracted to its own project
        ocws = inputs.ocws.packages.${pkgs.stdenv.hostPlatform.system}.ocws;

        # TUI cockpit for jj workspaces; pinned to the jj 0.47.1 PR until it
        # merges and a release contains the bump.
        jjfx = pkgs.callPackage ../pkgs/jjfx {};

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

        # Terminal CalDAV task manager (TUI) for the homelab PIM stack
        cfait = pkgs.callPackage ../pkgs/cfait {};

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
