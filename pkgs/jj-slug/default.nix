# Single source of truth for deriving jj bookmark slugs from conventional
# commit descriptions. Shared by jjpush (modules/home/shells/fish/functions/jj.nix)
# and the comin-autopush reconciler (modules/system/comin.nix) so the naming
# rule cannot drift between them.
{
  writeShellApplication,
  gnused,
}:
writeShellApplication {
  name = "jj-slug";
  runtimeInputs = [gnused];
  text = ''
    usage() {
      echo "usage: jj-slug \"<commit message first line>\"" >&2
      exit 2
    }
    [ "$#" -eq 1 ] || usage
    # "feat: add widget" -> "feat/add-widget"
    # "feat(homelab): add X" -> "feat/homelab-add-X"
    printf '%s' "$1" |
      sed -E 's/^([a-z]+)\(([^)]*)\):/\1\/\2/; s/^([a-z]+):[[:space:]]*/\1\//; s/ /-/g; s/[^a-zA-Z0-9_\/-]//g'
  '';
}
