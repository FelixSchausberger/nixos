{inputs, ...}: {
  imports = [
    ../../modules/system/sops-common.nix
    inputs.sops-nix.nixosModules.sops
  ];
}
