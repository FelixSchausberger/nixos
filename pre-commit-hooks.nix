{inputs, ...}: {
  imports = [inputs.pre-commit-hooks.flakeModule];

  perSystem.pre-commit = {
    settings.excludes = [
      "flake.lock"

      # Exclude because of pipe operators
      "home/default.nix"
      "home/profiles/default.nix"
      "hosts/default.nix"

      "/per/repos/magazino"
    ];

    settings.hooks = {
      alejandra.enable = true; # The Uncompromising Nix Code Formatter
      deadnix.enable = true; # Scan Nix files for dead code (unused variable bindings).
      flake-checker.enable = true; # Run health checks on your flake-powered Nix projects.
      markdownlint.enable = true; # Style checker and linter for markdown files.
      nil.enable = true; # Incremental analysis assistant for writing in Nix.

      prettier = {
        enable = true;
        excludes = [".js" ".md" ".ts"];
      };
    };
  };
}
