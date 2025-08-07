{inputs, ...}: {
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
      inputs.zed-extensions.overlays.default
    ];
  };
}
