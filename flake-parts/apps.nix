{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    apps = let
      # Single source of truth: flake.lib.hosts. WSL hosts are excluded from
      # installer apps because disko partitioning does not apply to them.
      installableHosts = builtins.filter (
        name: !(inputs.self.lib.hosts.${name}.isWsl or false)
      ) (builtins.attrNames inputs.self.lib.hosts);
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
