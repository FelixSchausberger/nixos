# Point comin's per-host testing branch at a change so a development host
# running the local remote applies it with switch-to-configuration test (no
# bootloader change). The branch must sit on top of main@origin: comin
# rejects a testing branch that is not a descendant of the selected main.
#
# The testing branch is a local-only channel: comin fetches it from the
# colocated checkout (modules/system/comin.nix), whose origin-side testing
# slot is disabled with "keep a stray GitHub testing branch from being
# selected" as the reason. A forge copy of the branch therefore has no
# consumer, and it does real harm: jjpush reuses any tracked bookmark near @
# as its PR head, so a testing bookmark parked at the commit under review
# becomes the PR head of an unrelated change (observed on #653 and #661).
# Every run therefore clears a stray remote copy before re-setting the
# branch: jj git push --deleted pushes ALL tracked deleted bookmarks, so the
# deletion set is verified against a dry-run and anything besides the
# testing branch is reported for manual handling instead of side-effected.
{
  writeShellApplication,
  jujutsu,
  coreutils,
  gnugrep,
}:
writeShellApplication {
  name = "jjtest";
  runtimeInputs = [
    jujutsu
    coreutils
    gnugrep
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

    # Stray-remote cleanup: comin reads the local checkout either way, so a
    # failed deletion warns but never blocks a test deploy. The detection
    # matches the @origin lines jj prints for a remote copy; an untracked
    # remote ref (no tracked deletion pending) lands in the manual path.
    if jj bookmark list "$bookmark" --remote origin 2>/dev/null | grep -q '@origin'; then
      jj bookmark delete "$bookmark"
      # jj prints push summaries on stderr, so both streams go into the
      # dry-run capture: stdout is empty in practice.
      dry="$(jj git push --deleted --dry-run 2>&1 || true)"
      deletion_count="$(grep -cE '^[[:space:]]*bookmark:' <<<"$dry" || true)"
      if [ "$deletion_count" = "1" ] && grep -qE "^[[:space:]]*bookmark:[[:space:]]*$bookmark \\[delete" <<<"$dry"; then
        jj git push --deleted >/dev/null 2>&1
        echo "Deleted the stray remote $bookmark ref."
      else
        echo "Warning: a remote $bookmark ref exists, but the pending tracked-bookmark deletions in this clone cover more than the testing branch:" >&2
        printf '%s\n' "$dry" | sed 's/^/  /' >&2
        echo "Manual cleanup keeps the change scoped: jj bookmark delete $bookmark && jj git push --deleted" >&2
      fi
    fi

    # The testing branch is deliberately resettable: comin applies it with
    # `test`, never `switch`, so moving it backwards is safe.
    jj bookmark set "$bookmark" -r "$rev" -B

    echo "Set $bookmark -> $(jj log --no-graph -r "$rev" -T 'commit_id.short()')"
    echo "comin applies it with switch-to-configuration test within one poll"
    echo "(no bootloader change). Watch progress with: comin status"
  '';
}
