{
  self,
  inputs,
  ...
}: {
  perSystem = {pkgs, ...}: let
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
          git
          inotify-tools # File system watching for niri-watch
          jq # JSON processing for profiling and build scripts
          just # Task runner for development workflows
          markdownlint-cli # Markdown linter used by the treefmt markdownlint formatter
          nix-update # Bump versions/hashes of pinned packages in pkgs/
          prettier
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
