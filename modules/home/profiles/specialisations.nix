{
  lib,
  osConfig,
  ...
}: {
  # Home-manager specialisations follow system specialisations
  # This module automatically creates home specialisations to match system specialisations
  #
  # When the system has specialisations defined, this module ensures home-manager
  # configurations are updated accordingly for each specialisation.

  config = let
    # Check if system has specialisations
    hasSystemSpecs = osConfig ? specialisation && osConfig.specialisation != {};
  in
    lib.mkIf hasSystemSpecs {
      # Automatically create home specialisations for each system specialisation
      # This ensures home configuration follows system configuration
      # For now, this is a placeholder - home.specialisation support in home-manager
      # is still experimental, so we rely on system specialisations to cascade properly

      # Future enhancement: when home-manager specialisation support stabilizes,
      # WM-specific home configurations can be added here.
    };
}
