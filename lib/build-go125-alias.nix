# The nixos-unstable channel removed buildGo125Module when Go 1.25 hit
# end-of-life (26.11pre1074753). sops-nix's module resolves its install helper
# from the consuming host's package set (config.sops.package defaults to
# (pkgs.callPackage ../.. {}).sops-install-secrets, which names
# buildGo125Module), so the alias throw hits every deployment regardless of
# sops-nix input follows. Map the removed alias onto the current
# buildGoModule; the Go 1.25 source code builds under the channel's newer Go.
#
# Shared by the host overlay set (modules/system/nixpkgs-overlays.nix) and the
# VM tests, which build from a bare package set and import sops-nix directly.
_final: prev: {
  buildGo125Module = prev.buildGoModule;
}
