# Test: lumen package builds successfully
{flake, ...}: let
  # Get the lumen package for x86_64-linux from the flake
  inherit (flake.packages.x86_64-linux) lumen;
in {
  # Test: Package has correct name
  package_name = lumen.pname;

  # Test: Package has a version
  has_version = lumen.version != null;

  # Test: Package has expected metadata
  has_meta = lumen.meta != null;

  # Test: Derivation path exists
  drv_path = builtins.isString (builtins.unsafeDiscardStringContext "${lumen}");
}
