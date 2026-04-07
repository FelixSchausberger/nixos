{
  description = "Rust CLI tool template for NixOS tools";

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
      }: let
        cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);

        # Common dependencies for system tools
        commonDeps = [
          # Add system libraries your tool might need
          # pkgs.libiconv
          # pkgs.openssl
          # pkgs.sqlite
          # pkgs.pkg-config
        ];

        # Runtime dependencies (available in PATH)
        runtimeDeps = [
          # Add tools your binary needs at runtime
          # pkgs.git
          # pkgs.curl
          # pkgs.zfs
        ];
      in {
        # Main package
        packages.default = pkgs.rustPlatform.buildRustPackage {
          inherit (cargoToml.package) name version;
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          buildInputs = commonDeps;
          nativeBuildInputs = with pkgs;
            [
              pkg-config
            ]
            ++ commonDeps;

          # Wrap binary with runtime dependencies
          postInstall = ''
            wrapProgram $out/bin/${cargoToml.package.name} \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
          '';

          # Environment variables for build
          # PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          # OPENSSL_DIR = "${pkgs.openssl.dev}";
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.treefmt.build.devShell
          ];

          shellHook = ''
            # Setup development environment
            export RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}

            # Add any environment setup needed for development
            echo "🦀 Rust development environment ready!"
            echo "Available commands:"
            echo "  cargo run    - Run during development"
            echo "  cargo test   - Run tests"
            echo "  nix build    - Build with Nix"
            echo "  treefmt      - Format code"
          '';

          buildInputs = commonDeps ++ runtimeDeps;
          nativeBuildInputs = with pkgs; [
            # Rust toolchain
            rustc
            cargo
            cargo-watch
            cargo-edit
            rust-analyzer

            # Development tools
            just
            pkg-config

            # Debugging tools
            gdb
            valgrind
          ];
        };

        # Code formatting
        treefmt.config = {
          projectRootFile = "flake.nix";
          programs = {
            nixpkgs-fmt.enable = true;
            rustfmt.enable = true;
          };
        };

        # Additional packages (if you need variants)
        # packages.tool-debug = packages.default.override {
        #   # Debug build configuration
        # };
      };
    };
}
