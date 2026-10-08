{inputs, ...}: {
  # Nix-on-Droid phone environment (aarch64 Android), a separate module system
  # from NixOS. Kept isolated from the fleet so a failure here cannot affect
  # any nixosConfiguration. Apply from the phone with
  # `nix-on-droid switch --flake .#phone`.
  flake.nixOnDroidConfigurations.phone = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import inputs.nixpkgs {system = "aarch64-linux";};
    modules = [../droid];

    # Forwarded into the Nix-on-Droid module system so droid/default.nix can
    # hand them to Home Manager: droid/home.nix reads inputs.self.lib, and the
    # reused starship.nix leaf reads hostConfig.isGui.
    extraSpecialArgs = {
      inherit inputs;
      hostConfig = {isGui = false;};
    };
  };
}
