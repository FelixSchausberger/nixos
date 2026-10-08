# Thin fish wrappers around the jj workspace workflow commands. The commands
# themselves are derivations in pkgs/jj-tools, exposed on PATH here so both
# interactive fish and automation invoke the same shell-agnostic wrapper.
{
  config,
  inputs,
  pkgs,
  ...
}: let
  jjTools = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  home.packages = [
    jjTools.jj-tidy
    jjTools.jjwork
    jjTools.jjpush
    jjTools.jjtest
    jjTools.ocws
  ];

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

    jjtest = {
      description = "Deploy current change to comin's testing branch (test, no bootloader)";
      body = ''
        # Run the shell-agnostic wrapper so automation and non-fish shells behave the same.
        command jjtest $argv
      '';
    };

    ocws = {
      description = "Create a jj workspace and run opencode in it (isolated parallel agent)";
      body = ''
        # Run the shell-agnostic wrapper so automation and non-fish shells behave the same.
        command ocws $argv
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
            ${config.home.homeDirectory}/.local/bin/nvedit $temp_file
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
        # Resolve the repo explicitly: gh cannot infer it without a .git, which
        # a jj secondary workspace does not have.
        set -l repo (command jj git remote list 2>/dev/null | sed -n 's/^origin[[:space:]]\{1,\}//p' | sed -E 's#\.git$##; s#^.*[:/]([^/]+/[^/]+)$#\1#')
        if test -n "$repo"
          set -lx GH_REPO $repo
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
        set -l repo (command jj git remote list 2>/dev/null | sed -n 's/^origin[[:space:]]\{1,\}//p' | sed -E 's#\.git$##; s#^.*[:/]([^/]+/[^/]+)$#\1#')
        if test -n "$repo"
          set -lx GH_REPO $repo
        end
        command gh pr view --web $pr_ref
      '';
    };
  };

  programs.fish.interactiveShellInit = ''
    # Completions for workflow commands (jj itself uses its vendored dynamic completions)
    complete -c jjpush -d "Push and create PR with auto-merge"
    complete -c jjtest -d "Deploy current change to comin's testing branch"
    complete -c jjdescribe -d "Update description with AI suggestion"

    # PR status completions
    complete -c prst -d "View current change's PR status"
    complete -c prweb -d "Open current change's PR in browser"
  '';
}
