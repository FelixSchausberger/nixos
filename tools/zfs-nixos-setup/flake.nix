{
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
        nonRustDeps = with pkgs; [
          libiconv
          openssl
          pkg-config
          # ZFS specific dependencies
          parted
          zfs
          dosfstools
          cryptsetup
          util-linux
          coreutils
        ];
      in {
        # Rust package
        packages.default = pkgs.rustPlatform.buildRustPackage {
          inherit (cargoToml.package) name version;
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          buildInputs = nonRustDeps;

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          # Add runtime dependencies to wrapper script
          postInstall = ''
            wrapProgram $out/bin/zfs-nixos-setup \
              --prefix PATH : ${pkgs.lib.makeBinPath nonRustDeps}
          '';
        };

        # Rust dev environment
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.treefmt.build.devShell
          ];
          shellHook = ''
            # For rust-analyzer 'hover' tooltips to work.
            export RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}

            # Make sure PATH includes all the tools we need
            export PATH=${pkgs.lib.makeBinPath nonRustDeps}:$PATH
          '';
          buildInputs = nonRustDeps;
          nativeBuildInputs = with pkgs; [
            rustc
            cargo
            cargo-watch
            rust-analyzer
            pkg-config
          ];
        };

        # Add your auto-formatters here.
        treefmt.config = {
          projectRootFile = "flake.nix";
          programs = {
            nixpkgs-fmt.enable = true;
            rustfmt.enable = true;
          };
        };
      };
    };
}
