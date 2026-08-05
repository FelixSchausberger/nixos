{
  inputs,
  pkgs,
  ...
}: let
  jjworkCmd = pkgs.writeShellApplication {
    name = "jjwork";
    runtimeInputs = [pkgs.jujutsu];
    text = ''
      set -euo pipefail

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

      # Garbage-collect leftover local bookmarks whose remote branch no longer
      # exists on origin. With delete-branch-on-merge, a missing @origin ref
      # means the PR was merged or the branch was removed; the commits stay
      # reachable in history, so dropping the pointer is safe. The current
      # bookmark and main are always kept.
      current_bookmark=$(jj bookmark list -r '@' 2>/dev/null | grep -E '^[^ :]+:' | sed 's/:.*//' | head -1) || true
      echo "Cleaning up leftover bookmarks..."
      for bm in $(jj bookmark list 2>/dev/null | grep -E '^[^ :]+:' | sed 's/:.*//'); do
        [ "$bm" = "main" ] && continue
        [ "$bm" = "$current_bookmark" ] && continue
        if ! jj bookmark list --all "$bm" 2>/dev/null | grep -q '^  @origin'; then
          if jj bookmark delete "$bm" 2>/dev/null; then
            echo "  deleted leftover bookmark: $bm"
          fi
        fi
      done

      echo ""
      echo "Working copy is based on main@origin. No conflicts detected."
      echo ""
    '';
  };

  jjpushCmd = pkgs.writeShellApplication {
    name = "jjpush";
    runtimeInputs = [pkgs.jujutsu pkgs.gh];
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

        # "feat: add widget" → "feat/add-widget"
        # "feat(homelab): add X" → "feat/homelab-add-X"
        bookmark="$(printf '%s' "$first_line" | sed -E 's/^([a-z]+)\(([^)]*)\):/\1\/\2/; s/^([a-z]+):[[:space:]]*/\1\//; s/ /-/g; s/[^a-zA-Z0-9_/-]//g')"
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

      # Create PR with auto-merge label.
      echo ""
      echo "Creating pull request with auto-merge..."
      if ! gh pr create --fill --label auto-merge --head "$bookmark"; then
        echo "Failed to create PR" >&2
        echo "   You may need to create it manually"
        exit 1
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
  };
in {
  home.packages = [jjworkCmd jjpushCmd];

  programs.fish.functions = {
    # Jujutsu management commands
    jjwork = {
      description = "Rebase onto main and create clean working commit (run before any work)";
      body = ''
        # Run the shell-agnostic wrapper so automation and non-fish shells behave the same.
        command jjwork $argv
      '';
    };

    jjpush = {
      description = "Push current change and create PR with auto-merge";
      body = ''
        # Run the shell-agnostic wrapper so automation and non-fish shells behave the same.
        command jjpush $argv
      '';
    };

    jjdescribe = {
      description = "Update commit description with AI-powered suggestion";
      body = ''
        echo "Generating commit message suggestion with lumen..."
        echo ""

        # Generate suggestion using lumen
        set -l suggestion (${
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.lumen
        }/bin/lumen draft 2>/dev/null)

        if test -z "$suggestion"
          echo "Failed to generate suggestion" >&2
          echo "   Falling back to manual describe"
          command jj describe
          return $status
        end

        # Display suggestion
        echo "Suggested commit message:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$suggestion"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Prompt user for action
        echo "Options:"
        echo "  [a] Accept suggestion"
        echo "  [e] Edit suggestion"
        echo "  [c] Write custom message"
        echo "  [q] Cancel"
        echo ""
        read -P "Choose action: " -n 1 action
        echo ""

        switch $action
          case a A
            # Accept suggestion
            command jj describe -m "$suggestion"
            if test $status -eq 0
              echo ""
              echo "Commit description updated"
            else
              echo "Failed to update description" >&2
              return 1
            end

          case e E
            # Edit suggestion - write to temp file and open in editor
            set -l temp_file (mktemp)
            echo "$suggestion" > $temp_file
            ${pkgs.helix}/bin/hx $temp_file
            set -l edited_msg (cat $temp_file)
            rm $temp_file

            if test -n "$edited_msg"
              command jj describe -m "$edited_msg"
              if test $status -eq 0
                echo ""
                echo "Commit description updated"
              else
                echo "Failed to update description" >&2
                return 1
              end
            else
              echo "Empty message, aborting" >&2
              return 1
            end

          case c C
            # Write custom message
            command jj describe

          case q Q
            echo "Cancelled" >&2
            return 0

          case '*'
            echo "Invalid option" >&2
            return 1
        end
      '';
    };

    prst = {
      description = "View current change's PR status without opening a browser";
      body = ''
        set -l pr_ref $argv[1]
        if test -z "$pr_ref"
          set -l bookmark (command jj bookmark list -r 'ancestors(@, 5) & bookmarks()' -T 'name' 2>/dev/null | head -1)
          if test -z "$bookmark"
            echo "No bookmark on the current change. Pass a PR number or branch explicitly." >&2
            return 1
          end
          set pr_ref $bookmark
        end
        command gh pr view $pr_ref $argv[2..]
      '';
    };

    prweb = {
      description = "Open current change's PR in the browser";
      body = ''
        set -l pr_ref $argv[1]
        if test -z "$pr_ref"
          set -l bookmark (command jj bookmark list -r 'ancestors(@, 5) & bookmarks()' -T 'name' 2>/dev/null | head -1)
          if test -z "$bookmark"
            echo "No bookmark on the current change. Pass a PR number or branch explicitly." >&2
            return 1
          end
          set pr_ref $bookmark
        end
        command gh pr view --web $pr_ref
      '';
    };
  };

  programs.fish.interactiveShellInit = ''
    # Completions for workflow commands (jj itself uses its vendored dynamic completions)
    complete -c jjpush -d "Push and create PR with auto-merge"
    complete -c jjdescribe -d "Update description with AI suggestion"

    # PR status completions
    complete -c prst -d "View current change's PR status"
    complete -c prweb -d "Open current change's PR in browser"
  '';
}
