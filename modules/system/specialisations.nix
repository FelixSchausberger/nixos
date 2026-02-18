{
  lib,
  config,
  ...
}: {
  # Generate NixOS specialisations from hostConfig.specialisations
  # Note: hostConfig.specialisations option is defined in hosts/shared.nix
  config.specialisation =
    lib.mapAttrs (_name: spec: {
      inheritParentConfig = true;
      configuration = {
        # Override WM list if specified
        hostConfig.wms = lib.mkIf (spec.wms != null) (lib.mkForce spec.wms);

        # Apply performance profile
        hostConfig.performanceProfile = lib.mkForce spec.profile;

        # Apply extra configuration (which can include imports internally)
        imports = [spec.extraConfig];
      };
    })
    config.hostConfig.specialisations;
}
