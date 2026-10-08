# Rebase the working copy onto main@origin, guarding described-vs-WIP and
# conflicts, then run jj-tidy. The fetch+rebase+verify+cleanup pipeline that
# every session starts with; kept in one place so automation and interactive
# use behave the same.
{
  writeShellApplication,
  jujutsu,
  jj-tidy,
}:
writeShellApplication {
  name = "jjwork";
  runtimeInputs = [
    jujutsu
    jj-tidy
  ];
  text = ''
    set -euo pipefail

    # WIP guard: refuse to rebase an undescribed non-empty working copy.
    # `jj rebase` preserves the diff, so it never overwrites files — the
    # loss vectors are --skip-emptied dropping an @ whose diff emptied
    # against the new parent, and undescribed work becoming unreferenced
    # after a later `jj new`/abandon. Forcing describe-or-override first
    # keeps every change anchored. Automation carrying WIP intentionally
    # sets JJWORK_ALLOW_WIP=1.
    if [ "''${JJWORK_ALLOW_WIP:-0}" != "1" ] && [ -n "$(jj diff --name-only 2>/dev/null)" ]; then
      wip_desc="$(jj log --no-graph -r '@' -T 'description.first_line()' 2>/dev/null || true)"
      if [ -z "$wip_desc" ] || [ "$wip_desc" = "(no description set)" ]; then
        echo "Refusing to rebase: working copy has undescribed changes:" >&2
        jj diff --name-only 2>/dev/null >&2
        echo "" >&2
        echo "Describe first ('jjdescribe'), or re-run with JJWORK_ALLOW_WIP=1" >&2
        echo "to carry the WIP across the rebase." >&2
        exit 1
      fi
    fi

    echo "Fetching from remote..."
    jj git fetch

    # Warn if local main bookmark has diverged from origin — this indicates a commit
    # was made directly to the local main bookmark instead of going through a PR.
    local_main=$(jj log --no-graph -r 'main' -T 'commit_id' 2>/dev/null | tr -d '[:space:]') || true
    remote_main=$(jj log --no-graph -r 'main@origin' -T 'commit_id' 2>/dev/null | tr -d '[:space:]') || true
    if [ -n "$local_main" ] && [ -n "$remote_main" ] && [ "$local_main" != "$remote_main" ]; then
      echo ""
      echo "WARNING: local 'main' has diverged from 'main@origin'." >&2
      echo "  local  main:         $local_main" >&2
      echo "  main@origin:         $remote_main" >&2
      echo "This usually means a commit was made directly to main instead of via PR." >&2
      echo "Create a PR branch for that commit before continuing:" >&2
      echo "  jj bookmark set feat/my-change -r main" >&2
      echo "  jj git push --branch feat/my-change" >&2
      echo ""
    fi

    # Rebase onto the remote main, not the local bookmark.
    # Using main@origin prevents silently rebasing onto a stale local main.
    echo "Rebasing onto main@origin..."
    jj rebase -d 'main@origin' --skip-emptied

    # Detect and warn about conflicts — never allow abandon or silent failure
    if jj resolve --list 2>/dev/null | grep -q .; then
      echo ""
      echo "!! CONFLICTS DETECTED !!" >&2
      echo "Resolve them with: jj resolve" >&2
      jj resolve --list 2>/dev/null
      echo ""
      echo "After resolving, run: jj squash" >&2
      exit 1
    fi

    # Verify that the working copy is now a descendant of main@origin.
    # If not, the rebase may have moved @ to a stale branch instead of on top of main.
    main_in_ancestors=$(jj log --no-graph -r 'ancestors(@) & main@origin' -T 'change_id' 2>/dev/null | tr -d '[:space:]')
    if [ -z "$main_in_ancestors" ]; then
      echo ""
      echo "WARNING: working copy parent is not main@origin after rebase." >&2
      echo "Current ancestry:" >&2
      jj log --no-graph -r '@ | @-' -T 'commit_id.short() ++ " " ++ remote_bookmarks ++ " " ++ description.first_line()' 2>/dev/null >&2
      echo "" >&2
      echo "To fix: jj rebase -d 'main@origin'" >&2
      exit 1
    fi

    # Bookmark GC and stale-work hygiene live in jj-tidy: one tool, one job.
    # Interactive use keeps the full tidy by default; automation wanting a
    # bare fetch+rebase sets JJWORK_CLEANUP=0.
    if [ "''${JJWORK_CLEANUP:-1}" = "1" ]; then
      jj-tidy
    fi

    echo ""
    echo "Working copy is based on main@origin. No conflicts detected."
    echo ""
  '';
}
