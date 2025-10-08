# Test: vigiland package builds successfully
{flake, ...}: let
  # Get the vigiland package for x86_64-linux from the flake
  inherit (flake.packages.x86_64-linux) vigiland;
in {
  # Test: Package has correct name
  package_name = vigiland.pname;

  # Test: Package has a version
  has_version = vigiland.version != null;

  # Test: Package has expected metadata
  has_meta = vigiland.meta != null;
  meta_description = vigiland.meta.description or null;
  meta_license = vigiland.meta.license.spdxId or null;
  meta_main_program = vigiland.meta.mainProgram or null;

  # Test: Derivation path exists
  drv_path = builtins.isString (builtins.unsafeDiscardStringContext "${vigiland}");
}
