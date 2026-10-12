# Single source of truth for deriving jj bookmark slugs from conventional
# commit descriptions. Used by jjpush (pkgs/jj-tools/jjpush.nix).
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
    #
    # The type separator is the only '/' the slug keeps. A '/' carried in the
    # description ("... for pkgs/", "handle /etc/foo") otherwise leaves a
    # trailing slash or forks the branch into extra path segments, both of
    # which git rejects. '@' holds that separator while every other run of
    # non-alphanumerics folds to '-', then becomes '/'.
    printf '%s' "$1" |
      sed -E '
        s/^([a-z]+)\(([^)]*)\):[[:space:]]*/\1@\2-/;
        s/^([a-z]+):[[:space:]]*/\1@/;
        s/[^A-Za-z0-9_@]+/-/g;
        s/@/\//;
        s/^-+//;
        s/-+$//
      '
  '';
}
