# Push the current change and open a PR with the auto-merge label. Guards
# against pushing work that is not descended from main@origin, drops the
# empty undescribed commits a parallel session can leave between
# main@origin and @, derives the bookmark from the commit description via
# jj-slug, runs the repo quality checks, then pushes and creates the PR.
{
  writeShellApplication,
  jujutsu,
  gh,
  coreutils,
  gnugrep,
  gnused,
  jj-slug,
}:
writeShellApplication {
  name = "jjpush";
  runtimeInputs = [
    jujutsu
    gh
    coreutils
    gnugrep
    gnused
    jj-slug
  ];
  text = ''
    set -euo pipefail

    # Guard: refuse to push if the current change is not descended from
    # main@origin. Checking main@origin (not the local bookmark) prevents
    # silently pushing work that diverged from the actual remote main due
    # to local bookmark drift.
    if [ -z "$(jj log --no-graph -r 'ancestors(@) & main@origin' -T 'change_id' 2>/dev/null | tr -d '[:space:]')" ]; then
      echo "Error: current change is not based on main@origin." >&2
      echo "Run 'jjwork' first to rebase onto main@origin." >&2
      echo "" >&2
      echo "Current ancestry:" >&2
      jj log --no-graph -r '@ | @-' -T 'commit_id.short() ++ " " ++ remote_bookmarks ++ " " ++ description.first_line()' 2>/dev/null >&2
      exit 1
    fi

    # Drop empty undescribed commits between main@origin and @ (leftovers
    # from parallel sessions or abandoned experiments). Pushing a bookmark
    # whose introduced commit set includes them fails with "Won't push
    # commit ... has no description", while later invocations report
    # success because the local git-ref export already mirrors the intended
    # state - nothing reaches origin and PR creation then fails confusingly.
    # Abandoning an empty commit is lossless: jj rebases descendants over it.
    # NOTE: iterate newline-separated (one ID per line via ++ "\n") with a
    # while-read loop, never `for cid in $(...)`: word splitting fuses
    # multiple IDs into one token, `jj log -r` fails on it, and errexit
    # kills the script with zero output.
    jj log --no-graph -r '(main@origin..@) & ~::remote_bookmarks() & ~@' -T 'change_id ++ "\n"' 2>/dev/null |
      while IFS= read -r cid; do
        [ -n "$cid" ] || continue
        em="$(jj log --no-graph -r "$cid" -T 'if(empty, "y", "n")' 2>/dev/null || echo n)"
        fl="$(jj log --no-graph -r "$cid" -T 'description.first_line()' 2>/dev/null || true)"
        if [ "$em" = "y" ] && { [ -z "$fl" ] || [ "$fl" = "(no description set)" ]; }; then
          jj abandon "$cid" >/dev/null 2>&1 || true
        fi
      done

    # Anything else undescribed between main@origin and @ blocks the push
    # loudly instead of leaving origin without the work while every later
    # push reports success. Process substitution (not a pipe) keeps the
    # loop in the current shell so $blockers survives it.
    blockers=""
    while IFS= read -r cid; do
      [ -n "$cid" ] || continue
      fl="$(jj log --no-graph -r "$cid" -T 'description.first_line()' 2>/dev/null || true)"
      if [ -z "$fl" ] || [ "$fl" = "(no description set)" ]; then
        blockers="$blockers $(printf %.8s "$cid")"
      fi
    done < <(jj log --no-graph -r '(main@origin..@) & ~::remote_bookmarks() & ~@' -T 'change_id ++ "\n"' 2>/dev/null)
    if [ -n "$blockers" ]; then
      echo "Error: undescribed commits remain between main@origin and @:$blockers" >&2
      echo "Describe ('jj describe -r <change> -m \"...\"') or abandon them before pushing." >&2
      exit 1
    fi

    # Search ancestors for an existing feature bookmark. The main bookmark
    # always sits on the parent commit after a rebase, so it is excluded;
    # otherwise the auto-create branch below would never trigger.
    bookmark="$(jj bookmark list -r 'ancestors(@, 5) & bookmarks() & ~bookmarks("main")' -T 'name' 2>/dev/null | head -1 | tr -d '[:space:]')"

    if [ -z "$bookmark" ]; then
      # No feature bookmark — auto-create one from the commit description's
      # first line. Resolve @ via change_id so the description is read from
      # the actual change even when @ is an empty working copy.
      change_id="$(jj log --no-graph -r '@' -T 'change_id' 2>/dev/null | tr -d '[:space:]')"
      first_line="$(jj log --no-graph -r "$change_id" -T 'description.first_line()' 2>/dev/null)"
      if [ -z "$first_line" ] || [ "$first_line" = "working copy" ]; then
        echo "No commit message set. Use 'jj describe' or 'jjdescribe' first." >&2
        exit 1
      fi

      # "feat: add widget" → "feat/add-widget" (shared jj-slug helper)
      bookmark="$(jj-slug "$first_line")"
      if ! printf '%s' "$bookmark" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9/._-]*$'; then
        printf "Invalid bookmark name: '%s'. Set manually with 'jj bookmark set <name>'.\n" "$bookmark" >&2
        exit 1
      fi
      jj bookmark set "$bookmark"
      echo "Auto-created bookmark: $bookmark"
    else
      # Auto-squash empty working copy into the bookmarked parent.
      if [ "$(jj log --no-graph -r '@' -T 'if(empty, "true", "false")' 2>/dev/null | tr -d '[:space:]')" = "true" ]; then
        jj squash 2>/dev/null || true
      fi
    fi

    # Run pre-push quality checks (best-effort; a broken formatter must not block push).
    echo "Running pre-push quality checks..."
    nix fmt 2>/dev/null || true
    prek run --all-files 2>/dev/null || true

    # Push changes (track the remote branch first if needed).
    echo "Pushing changes..."
    jj bookmark track "$bookmark" --remote=origin 2>/dev/null || true
    if ! jj git push; then
      echo "Failed to push changes" >&2
      exit 1
    fi

    # Create PR with auto-merge label. Title/body come from the bookmarked
    # commit's description instead of gh's --fill, which computes defaults
    # via git log and can fail outright (observed: doubled-branch argument
    # on long bookmark names).
    #
    # gh resolves the repository from the git checkout unless told otherwise,
    # and a jj secondary workspace has no .git. Derive owner/repo from the
    # origin remote so PR creation works there too.
    if [ -z "''${GH_REPO:-}" ]; then
      remote_url="$(jj git remote list 2>/dev/null | sed -n 's/^origin[[:space:]]\{1,\}//p')"
      GH_REPO="$(printf '%s' "$remote_url" | sed -E 's#\.git$##; s#^.*[:/]([^/]+/[^/]+)$#\1#')"
      export GH_REPO
    fi
    echo ""
    echo "Creating pull request with auto-merge..."
    pr_title="$(jj log --no-graph -r "$bookmark" -T 'description.first_line()' 2>/dev/null)"
    pr_body="$(jj log --no-graph -r "$bookmark" -T 'description' 2>/dev/null | tail -n +2 | sed '/./,$!d')"
    [ -n "$pr_body" ] || pr_body="$pr_title"
    if ! gh pr create --label auto-merge --head "$bookmark" --title "$pr_title" --body "$pr_body"; then
      # Re-run after a force-push: the branch may already have an open PR,
      # which is success (the push above updated it).
      if gh pr view "$bookmark" --json state --jq 'select(.state == "OPEN")' >/dev/null 2>&1; then
        echo "PR already open for $bookmark - pushed update"
      else
        echo "Failed to create PR" >&2
        echo "   You may need to create it manually"
        exit 1
      fi
    fi

    echo ""
    echo "Pull request created successfully!"
    echo ""
    echo "CI pipeline will run automatically"
    echo "PR will auto-merge when all checks pass"
    echo ""
    echo "View PR status:"
    echo "  gh pr view --web"
    echo ""
  '';
}
