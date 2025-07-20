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

        # Exclude host-specific placeholder secrets files
        "secrets/hosts/.*/secrets\\.yaml$"
      ];

      hooks = {
        alejandra.enable = true; # The Uncompromising Nix Code Formatter
        deadnix.enable = true; # Scan Nix files for dead code (unused variable bindings).
        flake-checker.enable = true; # Run health checks on your flake-powered Nix projects.
        markdownlint.enable = true; # Style checker and linter for markdown files.
        statix.enable = true; # Lints and suggestions for Nix code
        prettier = {
          enable = true;
          excludes = [
            ".js"
            ".md"
            ".ts"
          ];
        };

        # Security enhancements from Magazino patterns
        ripsecrets.enable = true; # Detect secrets in code
        trim-trailing-whitespace.enable = true; # Clean up whitespace

        # YAML/TOML formatting for consistency
        yamlfmt.enable = true;
        taplo.enable = true; # TOML formatter

        # Security: Ensure sops secrets are encrypted
        pre-commit-hook-ensure-sops = {
          enable = true;
          files = "^secrets/secrets\\.yaml$"; # Only check main secrets file, not host placeholders
        };
      };
    };
  };
}
