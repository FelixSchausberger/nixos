{inputs, ...}: {
  imports = [inputs.pre-commit-hooks.flakeModule];

  perSystem = {
    pre-commit.settings = {
      excludes = [
        "flake.lock"

        # Exclude because of pipe operators
        "home/default.nix"
        "home/profiles/default.nix"
        "hosts/default.nix"

        "/per/repos/magazino"
      ];

      hooks = {
        alejandra.enable = true; # The Uncompromising Nix Code Formatter
        deadnix.enable = true; # Scan Nix files for dead code (unused variable bindings).
        flake-checker.enable = true; # Run health checks on your flake-powered Nix projects.
        markdownlint.enable = true; # Style checker and linter for markdown files.
        nil.enable = true; # Incremental analysis assistant for writing in Nix.
        prettier = {
          enable = true;
          excludes = [".js" ".md" ".ts"];
        };
        # Security: Ensure sops secrets are encrypted
        pre-commit-hook-ensure-sops = {
          enable = true;
          #   name = "Ensure sops secrets are encrypted";
          #   entry = "${inputs.pre-commit-hook-ensure-sops.packages.${system}.default}/bin/pre-commit-hook-ensure-sops";
          files = "secrets\\.yaml$|secrets\\.json$";
          #   language = "system";
        };
      };
    };
  };
}
