{
  lib,
  config,
  ...
}: {
  # Generate NixOS specialisations from hostConfig.specialisations
  # Note: hostConfig.specialisations option is defined in hosts/shared.nix
  config.specialisation =
    lib.mapAttrs (_: spec: {
      inheritParentConfig = true;
      configuration = {
        # Override WM list if specified
        hostConfig.wm = lib.mkIf (spec.wm != null) (lib.mkForce spec.wm);

        # Apply performance profile
        hostConfig.performanceProfile = lib.mkForce spec.profile;

        # Apply extra configuration
        imports = [spec.extraConfig];
      };
    })
    config.hostConfig.specialisations;
}
