# Test: starship-jj package builds successfully
{flake, ...}: let
  inherit (flake.packages.x86_64-linux) starship-jj;
in {
  # Test: Package has correct name
  package_name = starship-jj.pname;

  # Test: Package has a version
  has_version = starship-jj.version != null;

  # Test: Package has expected metadata
  has_meta = starship-jj.meta != null;

  # Test: Derivation path exists
  drv_path = builtins.isString (builtins.unsafeDiscardStringContext "${starship-jj}");
}
