_: {
  perSystem = {pkgs, ...}: {
    apps = {
      nixos-anywhere = import ../apps/nixos-anywhere.nix {inherit pkgs;};
      install-remote = import ../apps/install-remote.nix {inherit pkgs;};
    };
  };
}
