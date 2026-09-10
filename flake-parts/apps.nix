{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    apps = let
      # Installable hosts are exactly the deployed fleet. Shelf configs in
      # flake.legacyConfigurations are excluded, and WSL hosts are excluded
      # because disko partitioning does not apply to them.
      installableHosts = builtins.filter (
        name: !(inputs.self.lib.hosts.${name}.isWsl or false)
      ) (builtins.attrNames inputs.self.nixosConfigurations);
    in {
      nixos-anywhere = import ../apps/nixos-anywhere.nix {
        inherit pkgs;
        hosts = installableHosts;
      };
      install-remote = import ../apps/install-remote.nix {
        inherit pkgs;
        hosts = installableHosts;
      };
    };
  };
}
