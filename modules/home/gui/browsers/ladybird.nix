{pkgs, ...}: {
  # nixpkgs packages Ladybird master snapshots and serves the build from
  # cache.nixos.org, so nothing compiles locally. Zen keeps the MIME defaults.
  home.packages = [pkgs.ladybird];
}
