{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    # A jj secondary workspace has no .git, so git-based tooling cannot find a
    # repository. This wrapper gives prek a throwaway repository whose index
    # mirrors the workspace, leaving the primary checkout's index and jj state
    # untouched. `prek install` is a no-op in a workspace: jj does not use git
    # hooks; hooks run via prek/jjpush/CI.
    prekJj = pkgs.writeShellApplication {
      name = "prek";
      runtimeInputs = [pkgs.git pkgs.coreutils];
      text = ''
        set -euo pipefail
        if [ -d .jj ] && [ ! -e .git ]; then
          case "''${1:-}" in
            install | uninstall)
              echo "prek: jj workspace has no .git; skipping '$1' (jj does not use git hooks)" >&2
              exit 0
              ;;
          esac
          cache="''${XDG_CACHE_HOME:-$HOME/.cache}/prek-jj/$(printf '%s' "$PWD" | md5sum | cut -c1-16)"
          mkdir -p "$(dirname "$cache")"
          [ -d "$cache" ] || GIT_DIR="$cache" git init -q
          export GIT_DIR="$cache" GIT_WORK_TREE="$PWD"
          # Refresh the workspace-local index so `git ls-files` sees the tree.
          git add -A >/dev/null 2>&1 || true
        fi
        exec ${pkgs.prek}/bin/prek "$@"
      '';
    };

    # No host selects COSMIC, so its system module would otherwise never be
    # evaluated. Build the synthetic system's toplevel path and the local
    # clipboard applet so a stale option or package breaks CI instead of the
    # first host that enables COSMIC.
    cosmicEval = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        hostConfig = {
          hostName = "cosmic-eval";
          user = inputs.self.lib.user;
          isGui = true;
          wms = ["cosmic"];
        };
      };
      modules = [
        inputs.impermanence.nixosModules.impermanence
        ../modules/system/wm/cosmic.nix
        {
          nixpkgs.hostPlatform = system;
          networking.hostName = "cosmic-eval";
          fileSystems."/" = {
            device = "/dev/null";
            fsType = "ext4";
          };
          boot.loader.grub.enable = false;
          system.stateVersion = "26.11";
          users.groups.${inputs.self.lib.user} = {};
          users.users.${inputs.self.lib.user} = {
            isNormalUser = true;
            group = inputs.self.lib.user;
          };
        }
      ];
    };
  in {
    checks =
      (inputs.namaka.lib.load {
        src = ../tests;
        inputs = {
          namaka = inputs.namaka.lib;
          flake = self;
        };
      })
      // {
        # The daemon's Prometheus vocabulary is a contract with the homepage
        # cards, the health dashboard and the alert rules; an upstream rename
        # silently empties those surfaces otherwise. The daemon source is the
        # single emitter (the textfile export copies its /metrics response), so
        # every metric name the consumers query must appear there. Builds under
        # `nix flake check`/CI; the eval-only namaka step does not run it.
        vitals-consumer-contract = pkgs.runCommand "vitals-consumer-contract" {} ''
          consumers=$(${pkgs.gnugrep}/bin/grep -ohE 'vitals_[a-z_]+' \
            ${../modules/system/homelab/homepage.nix} \
            ${../modules/system/homelab/config-health-dashboard.json} \
            ${../modules/system/homelab/monitoring.nix} | ${pkgs.coreutils}/bin/sort -u)
          emitted=$(${pkgs.gnugrep}/bin/grep -ohE 'vitals_[a-z_]+' \
            ${inputs.vitals.outPath}/daemon/src/bin/daemon.rs | ${pkgs.coreutils}/bin/sort -u)
          missing=$(${pkgs.coreutils}/bin/comm -23 \
            <(printf '%s\n' "$consumers") <(printf '%s\n' "$emitted"))
          if [ -n "$missing" ]; then
            echo "ERROR: consumers query vitals metrics the pinned daemon does not emit:" >&2
            printf '%s\n' "$missing" >&2
            exit 1
          fi
          touch $out
        '';

        # The assertions in modules/system/homelab/monitoring.nix cover
        # dashboard structure (UIDs, element references, datasource UIDs) but
        # not query text, so a typo'd PromQL expression renders an empty panel
        # without failing the deploy. gcx parses PromQL and panel units
        # offline. The description and editability rules stay off because they
        # flag 97 style findings across these six dashboards and gate nothing.
        grafana-dashboard-lint =
          pkgs.runCommand "grafana-dashboard-lint" {
            nativeBuildInputs = [pkgs.gcx];
          } ''
            export HOME=$TMPDIR
            gcx dev lint run --disable panel-title-description --disable uneditable-dashboard -o compact \
              ${../modules/system/homelab/config-health-dashboard.json} \
              ${../modules/system/homelab/fritz-dashboard.json} \
              ${../modules/system/homelab/garmin-dashboard.json} \
              ${../modules/system/homelab/logs-dashboard.json} \
              ${../modules/system/homelab/power-dashboard.json}
            touch $out
          '';

        # Unit test for the comin post-deploy downgrade detector; also runs as
        # a prek hook on changes to tools/scripts/detect-downgrades.sh.
        detect-downgrades = pkgs.runCommand "detect-downgrades-unit-test" {} ''
          mkdir scripts
          cp ${../tools/scripts/detect-downgrades.sh} scripts/detect-downgrades.sh
          cp ${../tools/scripts/lib-downgrade-compare.sh} scripts/lib-downgrade-compare.sh
          cp ${../tools/scripts/test-detect-downgrades.sh} scripts/test-detect-downgrades.sh
          chmod +x scripts/*.sh
          ${pkgs.bash}/bin/bash scripts/test-detect-downgrades.sh
          touch $out
        '';

        # The Rookery project owns the full classifier test. This repo reads
        # the binary in the badge, the digest, the keybindings and the
        # lead/worker protocol, so its shapes are pinned here: the eight-field
        # counts order, the board headings, the wait marker round trip, gc's
        # refusal to reclaim unpushed work, and every `seat --json` field.
        rookery-consumer-contract =
          pkgs.runCommand "rookery-consumer-contract" {
            nativeBuildInputs = [
              self.packages.${pkgs.stdenv.hostPlatform.system}.rookery
              pkgs.jujutsu
              pkgs.git
              pkgs.sqlite
              pkgs.jq
            ];
          } ''
            cp ${../tools/scripts/test-rookery-contract.sh} test-rookery-contract.sh
            chmod +x test-rookery-contract.sh
            bash test-rookery-contract.sh
            touch $out
          '';

        # The kiosk profile lives on the persistence dataset, where Home
        # Manager's seed entries are read-only: the extensions directory is
        # 0555 with 0444 files and the rest are symlinks into the store. The
        # seed therefore only fills gaps. An earlier revision reinstalled every
        # file, which replaced the links with regular files (the next
        # activation moved them aside as .backup) and then failed to remove the
        # extension tree, leaving the browser unit in a restart loop.
        media-kiosk-profile-seed = let
          fixture = pkgs.runCommand "media-kiosk-profile-seed-fixture" {} ''
            mkdir -p $out/chrome $out/extensions
            printf 'user_pref("kiosk.fixture", true);\n' > $out/user.js
            printf '#navigator-toolbox { display: none; }\n' > $out/chrome/userChrome.css
            printf 'fixture extension\n' > $out/extensions/uBlock0@raymondhill.net.xpi
            : > $out/.keep
          '';
          seed = pkgs.callPackage ../modules/home/gui/media-kiosk-seed.nix {
            userJs = "${fixture}/user.js";
            userChrome = "${fixture}/chrome/userChrome.css";
            extensions = "${fixture}/extensions";
          };
        in
          pkgs.runCommand "media-kiosk-profile-seed-test" {} ''
            seed=${seed}/bin/media-kiosk-profile-seed

            # 1. A profile Home Manager already seeded: symlinks plus the
            #    read-only extensions directory, exactly as activation leaves
            #    it. The seed must change nothing and succeed.
            seeded=$TMPDIR/seeded
            profile=$seeded/.config/zen/kiosk
            mkdir -p "$profile/chrome" "$profile/extensions"
            ln -s ${fixture}/user.js "$profile/user.js"
            ln -s ${fixture}/.keep "$profile/.keep"
            ln -s ${fixture}/chrome/userChrome.css "$profile/chrome/userChrome.css"
            ln -s ${fixture}/extensions/uBlock0@raymondhill.net.xpi "$profile/extensions/uBlock0@raymondhill.net.xpi"
            chmod 0555 "$profile/extensions"
            HOME=$seeded $seed
            test -L "$profile/user.js"
            test -L "$profile/.keep"
            test -L "$profile/chrome/userChrome.css"
            test -L "$profile/extensions/uBlock0@raymondhill.net.xpi"
            test "$(stat -c %a "$profile/extensions")" = 555

            # 2. A profile the persistence mount emptied: the seed populates it
            #    from the store paths and exits 0.
            fresh=$TMPDIR/fresh
            profile=$fresh/.config/zen/kiosk
            mkdir -p "$profile"
            HOME=$fresh $seed
            cmp ${fixture}/user.js "$profile/user.js"
            cmp ${fixture}/chrome/userChrome.css "$profile/chrome/userChrome.css"
            cmp ${fixture}/extensions/uBlock0@raymondhill.net.xpi "$profile/extensions/uBlock0@raymondhill.net.xpi"
            test -e "$profile/.keep"

            # 3. A later start leaves existing entries alone, including one an
            #    older activation or the browser left as a regular file.
            rm "$profile/user.js"
            printf 'user_pref("kiosk.local", true);\n' > "$profile/user.js"
            HOME=$fresh $seed
            grep -q kiosk.local "$profile/user.js"
            test -L "$profile/extensions/uBlock0@raymondhill.net.xpi"

            touch $out
          '';

        cosmic-system = pkgs.runCommand "cosmic-system-eval" {} ''
          test -n "${builtins.unsafeDiscardStringContext cosmicEval.config.system.build.toplevel.drvPath}"
          test -x ${pkgs.callPackage ../pkgs/cosmic-ext-applet-clipboard-manager {}}/bin/cosmic-ext-applet-clipboard-manager
          touch $out
        '';
      };

    devShells.default = pkgs.mkShell {
      packages = with pkgs;
        [
          actionlint # GitHub Actions linter for pre-commit hooks
          alejandra
          bashInteractive
          deadnix
          fish
          flake-checker # Flake input health monitoring
          gcx # Offline Grafana dashboard linter (grafana-dashboard-lint)
          git
          inotify-tools # File system watching for niri-watch
          jq # JSON processing for profiling and build scripts
          just # Task runner for development workflows
          markdownlint-cli # Markdown linter used by the treefmt markdownlint formatter
          nix-update # Bump versions/hashes of pinned packages in pkgs/
          prettier
          python3 # Runs tools/scripts/grafana-dashboard-v2.py
          shellcheck # Shell script linting for pre-commit hooks
          pre-commit-hook-ensure-sops
          ssh-to-age
          statix
          taplo
          treefmt
          yamlfmt # YAML formatting for the pre-commit hook
          inputs.namaka.packages.${pkgs.stdenv.hostPlatform.system}.default # Snapshot testing
        ]
        ++ [prekJj];

      name = "nixos-config";

      # Only install pre-commit hooks in interactive shells, not CI
      shellHook = ''
        if [ -z "''${CI:-}" ]; then
          prek install
        fi
      '';
    };

    formatter = pkgs.treefmt;
  };
}
