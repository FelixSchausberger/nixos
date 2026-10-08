# Repository tidy janitor, split out of jjwork: drops merged leftover
# bookmarks and abandons stale off-main revisions. Pure jj, so it runs from
# any workspace - a secondary workspace has no .git, and the absorption test
# below must work there too. Named jj-tidy to avoid colliding with the
# interactive `just jj-hygiene` review recipe. jjwork invokes it by default;
# automation wanting a bare fetch+rebase sets JJWORK_CLEANUP=0.
{
  writeShellApplication,
  jujutsu,
}:
writeShellApplication {
  name = "jj-tidy";
  runtimeInputs = [
    jujutsu
  ];
  text = ''
    set -euo pipefail

    # Garbage-collect leftover bookmarks whose remote branch no longer exists
    # on origin. With GitHub "automatically delete head branches" + auto-merge,
    # a gone @origin ref means the PR was merged and the branch deleted; the
    # commits stay reachable in history, so dropping the pointer is safe.
    # Deleting a conflicted bookmark also resolves its conflicting targets,
    # and in this colocated repo removes the exported git branch.
    #
    # A bookmark is only deleted when its content is provably merged into
    # main@origin (target is an ancestor of main@origin, or it introduces no
    # diff on top of it) - so the working copy's own bookmark is cleaned up
    # once its PR merges. Unmerged work and main are always kept.
    #
    # Invariant: origin auto-deletes head branches on merge; jj-tidy drops the
    # local bookmark (and exported git branch) once @origin is gone. jj's own
    # fetch prunes the stale remote-tracking bookmark, which is what makes the
    # @origin lookup below fail (no git remote.origin.prune setting needed).
    echo "Cleaning up leftover bookmarks..."
    for bm in $(jj bookmark list -T 'name ++ "\n"' 2>/dev/null | sort -u); do
      [ "$bm" = "main" ] && continue

      # Remote branch still exists on origin -> active work, keep it.
      # With fetch.prune enabled, a remote-only deletion also lands here as a
      # failed @origin lookup.
      if jj log --no-graph -r "$bm@origin" -T 'commit_id' >/dev/null 2>&1; then
        continue
      fi

      if [ -n "$(jj log --no-graph -r "ancestors(main@origin) & bookmarks(\"$bm\")" -T 'commit_id' 2>/dev/null)" ] \
        || [ -z "$(jj diff --from 'main@origin' --to "bookmarks(\"$bm\")" --name-only 2>/dev/null)" ]; then
        if jj bookmark delete "$bm" 2>/dev/null; then
          echo "  deleted leftover bookmark: $bm"
        fi
      else
        echo "  keeping unmerged work: $bm (differs from main@origin)" >&2
      fi
    done

    # Stale local work: heads outside main@origin whose effect is provably
    # already present there. Candidates are handled per revision (commit
    # id), never per change id: a divergent change-id (several visible
    # revisions) errors out when used directly, and each revision needs an
    # independent keep-or-drop decision.
    #
    # A revision is abandoned only when ALL of these hold:
    #   - not reachable from main@origin: revisions inside main pin merged
    #     history (e.g. as second parent of a GitHub merge-commit node),
    #     and rewriting them cascades into main and every descendant
    #   - carries no active remote bookmark (in-flight PR)
    #   - single parent (merge-node absorption semantics are ambiguous)
    #   - childless (dropping a parent rewrites all of its children)
    #   - fully absorbed: every path it touches is identical between
    #     main@origin and the revision, compared with jj diff per path - exact,
    #     unlike patch-id matching, and immune to how the content landed. Using
    #     jj rather than git lets jj-tidy run from any workspace, including the
    #     git-less secondary ones.
    # Anything else is reported for human review (just jj-hygiene).
    # Actionable divergence (outside main@origin) is reported at the end;
    # immutable merge-era divergence inside main@origin is intentionally
    # not enumerated - see the divergence block below.
    absorbed_count=0
    review_count=0
    for cid in $(jj log --no-graph -r 'heads(all() ~ (::main@origin | ancestors(@) | working_copies()))' -T 'commit_id ++ "\n"' 2>/dev/null); do
      desc=$(jj log --no-graph -r "$cid" -T 'description.first_line()' 2>/dev/null)
      when=$(jj log --no-graph -r "$cid" -T 'committer.timestamp().format("%Y-%m-%d")' 2>/dev/null)

      # Merged-history revision: untouchable even though its off-main
      # twins may be dropped alongside it.
      if [ -n "$(jj log --no-graph -r "ancestors(main@origin) & $cid" -T 'commit_id' 2>/dev/null)" ]; then
        continue
      fi

      active_remote=0
      for bm in $(jj bookmark list -r "$cid" -T 'name ++ "\n"' 2>/dev/null); do
        if jj log --no-graph -r "$bm@origin" -T 'commit_id' >/dev/null 2>&1; then
          active_remote=1
          break
        fi
      done
      [ "$active_remote" = "1" ] && continue

      if [ "$(jj log --no-graph -r "$cid-" -T 'commit_id ++ "\n"' 2>/dev/null | wc -l)" -gt 1 ]; then
        echo "  $when [merge node] ''${desc:-<no description>}" >&2
        review_count=$((review_count + 1))
        continue
      fi

      if [ -n "$(jj log --no-graph -r "$cid+" -T 'commit_id' 2>/dev/null)" ]; then
        echo "  $when [has descendants] $desc" >&2
        review_count=$((review_count + 1))
        continue
      fi

      differs=""
      for f in $(jj diff -r "$cid" --name-only 2>/dev/null); do
        if [ -n "$(jj diff --from 'main@origin' --to "$cid" -- "$f" 2>/dev/null)" ]; then
          differs="$differs $f"
        fi
      done

      if [ -z "$differs" ]; then
        echo "  $when [absorbed] ''${desc:-<no description>} -> abandoned"
        jj abandon "$cid" >/dev/null
        absorbed_count=$((absorbed_count + 1))
      else
        echo "  $when [DIFFERS:$differs] $desc" >&2
        review_count=$((review_count + 1))
      fi
    done

    # Divergence has two classes, and only one is actionable:
    #   - outside main@origin: mutable revisions, resolvable with
    #     `jj converge` (or `jj abandon` / `jj metaedit --update-change-id`
    #     on the redundant revision)
    #   - inside main@origin: merge-era duplicates where the same change
    #     landed twice under one change-id (a feature-branch draft pinned as
    #     the second parent of a GitHub merge commit, plus a later draft).
    #     Those are immutable; resolving them rewrites main and every
    #     descendant, so jj converge refuses by design. Report only the
    #     actionable set so this stays a signal, not recurring noise.
    divergent=$(jj log --no-graph -r 'divergent() & ~::main@origin' -T 'change_id.short() ++ "\n"' 2>/dev/null)
    if [ -n "$divergent" ]; then
      echo "  divergent changes outside main@origin (resolve with 'jj converge'):" >&2
      jj log --no-graph -r 'divergent() & ~::main@origin' -T '"    " ++ change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"' >&2
      review_count=$((review_count + 1))
    fi

    if [ "$absorbed_count" -gt 0 ] || [ "$review_count" -gt 0 ]; then
      echo "  stale work: $absorbed_count abandoned, $review_count need review"
      echo ""
    fi
  '';
}
