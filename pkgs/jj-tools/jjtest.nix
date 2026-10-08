# Point comin's per-host testing branch at a change so a development host
# running the local remote applies it with switch-to-configuration test (no
# bootloader change). The branch must sit on top of main@origin: comin
# rejects a testing branch that is not a descendant of the selected main.
{
  writeShellApplication,
  jujutsu,
  coreutils,
}:
writeShellApplication {
  name = "jjtest";
  runtimeInputs = [
    jujutsu
    coreutils
  ];
  text = ''
    set -euo pipefail

    rev="''${1:-@}"

    if [ -z "$(jj log --no-graph -r "ancestors($rev) & main@origin" -T 'change_id' 2>/dev/null | tr -d '[:space:]')" ]; then
      echo "Error: $rev is not based on main@origin." >&2
      echo "comin requires the testing branch to sit on top of origin/main." >&2
      echo "Run 'jjwork' first, then retry." >&2
      exit 1
    fi

    host="$(hostname -s)"
    bookmark="testing-$host"

    # The testing branch is deliberately resettable: comin applies it with
    # `test`, never `switch`, so moving it backwards is safe.
    jj bookmark set "$bookmark" -r "$rev" -B

    echo "Set $bookmark -> $(jj log --no-graph -r "$rev" -T 'commit_id.short()')"
    echo "comin applies it with switch-to-configuration test within one poll"
    echo "(no bootloader change). Watch progress with: comin status"
  '';
}
