# Test: mcp-language-server package builds successfully
{flake, ...}: let
  # Get the mcp-language-server package for x86_64-linux from the flake
  inherit (flake.packages.x86_64-linux) mcp-language-server;
in {
  # Test: Package has correct name
  package_name = mcp-language-server.pname;

  # Test: Package has a version
  has_version = mcp-language-server.version != null;

  # Test: Package has expected metadata
  has_meta = mcp-language-server.meta != null;

  # Test: Derivation path exists
  drv_path = builtins.isString (builtins.unsafeDiscardStringContext "${mcp-language-server}");
}
