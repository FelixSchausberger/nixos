{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    apps = let
      # Installable hosts are exactly the deployed fleet. Shelf configs in
      # flake.legacyConfigurations are excluded, and WSL hosts are excluded
      # because disko partitioning does not apply to them.
      installableHosts = builtins.filter (
        name: !(inputs.self.lib.hosts.${name}.isWsl or false)
      ) (builtins.attrNames inputs.self.nixosConfigurations);

      # The self-hosted Vaultwarden the install tools talk to. Mirrors the
      # vaultwarden httpsPort option default (modules/system/homelab/
      # vaultwarden.nix) and the m920q caddyProxy tailnetDomain; kept as a
      # literal because resolving it from module config would drag the full
      # m920q evaluation into every app build.
      vaultwardenUrl = "https://m920q.tailf2f0ca.ts.net:8447";
    in {
      nixos-anywhere = import ../apps/nixos-anywhere.nix {
        inherit pkgs;
        hosts = installableHosts;
      };
      install-remote = import ../apps/install-remote.nix {
        inherit pkgs;
        inherit vaultwardenUrl;
        hosts = installableHosts;
      };
      # Unlike installableHosts, WSL hosts can own a sops recipient too; only
      # the ISO-driven disko path excludes them.
      new-host-keys = import ../apps/new-host-keys.nix {
        inherit pkgs;
        inherit vaultwardenUrl;
        hosts = builtins.attrNames inputs.self.nixosConfigurations;
      };
    };
  };
}
