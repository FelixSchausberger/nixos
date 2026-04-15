{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    makeISO = modules:
      (inputs.nixpkgs.lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        specialArgs = {
          inherit inputs;
          repoConfig = import ../config.nix;
        };
        inherit modules;
      }).config.system.build.isoImage;
  in {
    # Expose nixpkgs for easier local builds (e.g., nix build .#fishPlugins.autopair)
    legacyPackages = pkgs;

    packages = {
      lumen = pkgs.callPackage ../pkgs/lumen {};

      # Editor with Steel plugin support
      scooter-hx = pkgs.callPackage ../pkgs/scooter-hx {};

      # Applications
      quantumlauncher = pkgs.callPackage ../pkgs/quantumlauncher {};

      # Minimal installer ISO (fast rebuilds for testing)
      installer-iso-minimal = makeISO [../hosts/installer-minimal];

      # Full installer ISO (comprehensive recovery environment)
      installer-iso-full = makeISO [../hosts/installer];
    };
  };
}
