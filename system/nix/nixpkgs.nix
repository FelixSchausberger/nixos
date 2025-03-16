{inputs, ...}: {
  imports = [
    inputs.lix-module.nixosModules.default
  ];
  nixpkgs = {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "electron-25.9.0"
      ];
      allowBroken = true;
    };
    overlays = [
      inputs.nur.overlays.default
    ];
  };
}
