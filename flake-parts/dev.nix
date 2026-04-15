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
        bc # Required by calculate-coverage.sh for mathematical calculations
        deadnix
        fish
        flake-checker # Flake input health monitoring
        git
        inotify-tools # File system watching for niri-watch
        jq # JSON processing for quality metric scripts
        just # Task runner for development workflows
        prettier
        pre-commit-hook-ensure-sops
        prek
        ssh-to-age
        statix
        taplo
        inputs.namaka.packages.${pkgs.stdenv.hostPlatform.system}.default # Snapshot testing
      ];

      name = "nixos-config";

      shellHook = ''
        prek install
      '';
    };

    formatter = pkgs.alejandra;
  };
}
