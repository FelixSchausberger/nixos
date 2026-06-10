# Early import stage for sops-nix so secrets are available to later host modules.
{inputs, ...}: {
  imports = [
    ../../modules/system/sops-common.nix
    inputs.sops-nix.nixosModules.sops
  ];
}
