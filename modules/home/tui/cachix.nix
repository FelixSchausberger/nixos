{pkgs, ...}: {
  # Cachix CLI for on-demand pushes (`just build-push-cache`). Host closures are
  # warmed by the CI cachix-push workflow, so no local watch-store daemon runs
  # here: it uploaded ad-hoc builds over the home uplink and saturated it.
  home.packages = [pkgs.cachix];
}
