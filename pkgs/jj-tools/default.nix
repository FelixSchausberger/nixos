# One derivation per jj workflow command, split out of the home-manager module
# that wires them to fish so each tool reads and is reviewed on its own.
# jjwork rebases onto main@origin and calls jj-tidy; jjpush turns a described
# change into an auto-merge PR; jjtest points comin's per-host testing bookmark
# at a change; ocws creates and reclaims the per-agent workspaces they run in.
# All are shell-agnostic writeShellApplication wrappers so automation and
# non-fish shells behave the same.
{
  callPackage,
  jj-slug,
}: let
  jj-tidy = callPackage ./jj-tidy.nix {};
in {
  inherit jj-tidy;
  jjwork = callPackage ./jjwork.nix {inherit jj-tidy;};
  jjpush = callPackage ./jjpush.nix {inherit jj-slug;};
  jjtest = callPackage ./jjtest.nix {};
  ocws = callPackage ./ocws.nix {};
}
