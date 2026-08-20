{
  self,
  inputs,
  ...
}: {
  perSystem = {pkgs, ...}: {
    checks = inputs.namaka.lib.load {
      src = ../tests;
      inputs = {
        namaka = inputs.namaka.lib;
        flake = self;
      };
    };

    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        actionlint # GitHub Actions linter for pre-commit hooks
        alejandra
        bashInteractive
        deadnix
        fish
        flake-checker # Flake input health monitoring
        git
        go # Required by yamlfmt pre-commit hook
        inotify-tools # File system watching for niri-watch
        jq # JSON processing for profiling and build scripts
        just # Task runner for development workflows
        markdownlint-cli # Markdown linter used by the treefmt markdownlint formatter
        prettier
        shellcheck # Shell script linting for pre-commit hooks
        pre-commit-hook-ensure-sops
        prek
        ssh-to-age
        statix
        taplo
        treefmt
        inputs.namaka.packages.${pkgs.stdenv.hostPlatform.system}.default # Snapshot testing
      ];

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
