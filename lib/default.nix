# Utility functions for home profile imports
{
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
  importHelpers = import ./import.nix {inherit lib;};
in {
  # Create consistent profile imports with automatic host detection
  mkProfileImports = hosts: let
    mkProfileForHost = host: {
      name = "${defaults.system.user}@${host}";
      value = importHelpers.importProfile host;
    };
  in
    lib.listToAttrs (map mkProfileForHost hosts);
}
