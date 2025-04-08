{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.default
    inputs.nur.modules.nixos.default
    # inputs.sops-nix.homeManagerModules.sops
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    backupFileExtension = "backup";

    extraSpecialArgs = {
      secrets = builtins.fromJSON (builtins.readFile "${inputs.self}/secrets/secrets.json");
    };

    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}
