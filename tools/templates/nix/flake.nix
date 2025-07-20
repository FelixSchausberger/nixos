{
  description = "Nix tool template for NixOS configuration utilities";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    # Dev tools
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import inputs.systems;
      imports = [
        inputs.treefmt-nix.flakeModule
      ];
      perSystem = {
        config,
        pkgs,
        ...
      }: {
        packages = {
          # Main package - a Nix-based tool
          default = pkgs.writeShellApplication {
            name = "my-nix-tool"; # CHANGE THIS: Update to your tool name

            # Runtime dependencies available in PATH
            runtimeInputs = with pkgs; [
              # Add tools your script needs
              coreutils
              findutils
              gnused
              gnugrep
              jq
              # nix
              # git
              # curl
            ];

            text = builtins.readFile ./src/main.sh;
          };

          # Alternative: Pure Nix function package
          nix-function = pkgs.callPackage ./src/default.nix {};

          # Alternative: Python-based tool
          python-tool = pkgs.python3Packages.buildPythonApplication {
            pname = "my-python-tool"; # CHANGE THIS
            version = "0.1.0";
            src = ./src;

            propagatedBuildInputs = [
              # Add Python dependencies
              # pkgs.python3Packages.requests
              # pkgs.python3Packages.pyyaml
              # pkgs.python3Packages.click
            ];

            # If you have a setup.py or pyproject.toml
            # pyproject = true;
          };
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.treefmt.build.devShell
          ];

          buildInputs = with pkgs; [
            # Shell scripting tools
            shellcheck
            shfmt

            # Nix development
            nixd # Nix language server
            nix-tree
            nix-diff

            # Python development (if using Python)
            python3
            python3Packages.pip
            python3Packages.virtualenv

            # General development tools
            jq
            yq
            just
          ];

          shellHook = ''
            echo "📦 Nix tool development environment ready!"
            echo "Available commands:"
            echo "  nix build          - Build the tool"
            echo "  nix run            - Run the tool"
            echo "  shellcheck src/*.sh - Check shell scripts"
            echo "  treefmt           - Format code"
          '';
        };

        # Apps for easy running
        apps.default = {
          type = "app";
          program = "${config.packages.default}/bin/my-nix-tool";
        };

        # Code formatting
        treefmt.config = {
          projectRootFile = "flake.nix";
          programs = {
            nixpkgs-fmt.enable = true;
            shellcheck.enable = true;
            shfmt.enable = true;
            # python formatting if using Python
            # black.enable = true;
            # isort.enable = true;
          };
        };
      };
    };
}
