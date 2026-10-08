{inputs, ...}: {
  # Nix-on-Droid phone environment (aarch64 Android), a separate module system
  # from NixOS. Kept isolated from the fleet so a failure here cannot affect
  # any nixosConfiguration. Apply from the phone with
  # `nix-on-droid switch --flake .#phone`.
  flake.nixOnDroidConfigurations.phone = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
    };
    modules = [../droid];
  };
}
