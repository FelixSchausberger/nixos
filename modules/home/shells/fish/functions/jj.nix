{
  inputs,
  pkgs,
  ...
}: {
  programs.fish.functions = {
    # Jujutsu management commands
    jj = {
      description = "Jujutsu VCS management commands";
      body = ''
        set -l subcommand $argv[1]
        set -l flags $argv[2..-1]

        # Show help if no subcommand provided or help requested
        if test -z "$subcommand" -o "$subcommand" = "--help" -o "$subcommand" = "-h"
          echo ""
          echo "Jujutsu VCS management commands:"
          echo "  jj log [--graph]   - Show change log"
          echo "  jj diff [--stat]   - Show diff"
          echo "  jj commit [-m]     - Create commit"
          echo "  jj sync            - Fetch and push"
          echo "  jj search          - Interactive file search"
          echo "  jj ui              - Open lazyjj TUI"
          echo ""
          echo "Workflow commands:"
          echo "  jjbranch (jjb)     - Create feature branch (optional, for experimental work)"
          echo "  jjdescribe         - Update description with AI suggestion"
          echo "  jjpush             - Push and create PR"
          echo ""
          echo "Dev-Main Workflow:"
          echo "  - Work on 'dev' branch by default"
          echo "  - Use 'jj describe' or 'jjdescribe' to commit changes"
          echo "  - Push with 'jj git push'"
          echo "  - Create feature branches (jjbranch) only for experimental work"
          echo ""
          echo "Note: Use 'lazyjj' for visual TUI operations"
          echo ""
          return 0
        end

        switch $subcommand
          case log l
            jj_log $flags
          case diff d
            jj_diff $flags
          case commit c
            jj_commit $flags
          case sync
            jj_sync $flags
          case search
            jj_search $flags
          case ui
            # Launch lazyjj TUI
            command lazyjj $flags
          case '*'
            # Pass through to actual jj command
            command jj $subcommand $flags
        end
      '';
    };

    jj_log = {
      description = "Show jj log";
      body = ''
        if contains -- "--graph" $argv
          command jj log --graph $argv
        else
          command jj log --limit 10 $argv
        end
      '';
    };

    jj_diff = {
      description = "Show jj diff";
      body = ''
        if contains -- "--stat" $argv
          command jj diff --stat $argv
        else
          command jj diff $argv
        end
      '';
    };

    jj_commit = {
      description = "Create jj commit";
      body = ''
        if test -n "$argv[1]" -a "$argv[1]" = "-m"
          command jj commit -m "$argv[2]"
        else
          command jj commit $argv
        end
      '';
    };

    jj_sync = {
      description = "Fetch and push";
      body = ''
        command jj git fetch
        if test $status -eq 0
          command jj git push $argv
        end
      '';
    };

    jj_search = {
      description = "Interactive file search with fzf";
      body = ''
        command jj files | ${pkgs.fzf}/bin/fzf --style full --scheme path \
          --border --padding 1,2 \
          --ghost 'Search jj files...' \
          --border-label ' Jujutsu Files ' --input-label ' Query ' --header-label ' File Type ' \
          --footer-label ' Hashes ' \
          --preview '${pkgs.bat}/bin/bat --theme=gruvbox-dark --color=always {}' \
          --bind 'result:bg-transform-list-label:if [[ -z $FZF_QUERY ]]; then echo " $FZF_MATCH_COUNT items "; else echo " $FZF_MATCH_COUNT matches for [$FZF_QUERY] "; fi' \
          --bind 'focus:bg-transform-preview-label:[[ -n {} ]] && printf " Previewing [%s] " {}' \
          --bind 'focus:+bg-transform-header:[[ -n {} ]] && file --brief {}' \
          --bind 'ctrl-r:change-list-label( Reloading... )+reload(sleep 0.5; jj files)' \
          --color 'border:#aaaaaa,label:#cccccc' \
          --color 'preview-border:#9999cc,preview-label:#ccccff' \
          --color 'list-border:#669966,list-label:#99cc99' \
          --color 'input-border:#996666,input-label:#ffcccc' \
          --color 'header-border:#6699cc,header-label:#99ccff' \
          --color 'footer:#ccbbaa,footer-border:#cc9966,footer-label:#cc9966'
      '';
    };

    jjbranch = {
      description = "Create a new branch with conventional commit format";
      body = ''
        # Interactive type selection with fzf
        set -l type (echo -e "feat\nfix\nchore\ndocs\ntest\nrefactor\nperf" | \
          ${pkgs.fzf}/bin/fzf \
            --height=~40% \
            --border \
            --prompt="Select type: " \
            --header="Choose conventional commit type" \
            --preview="echo {}" \
            --preview-window=up:1)

        if test -z "$type"
          echo "❌ No type selected, aborting"
          return 1
        end

        # Prompt for description
        echo ""
        read -P "Enter description (lowercase, hyphens only): " description

        if test -z "$description"
          echo "❌ No description provided, aborting"
          return 1
        end

        # Validate description format
        if not string match -qr '^[a-z0-9-]+$' "$description"
          echo "❌ Invalid description format"
          echo "   Use lowercase letters, numbers, and hyphens only"
          return 1
        end

        # Create branch name
        set -l branch_name "$type/$description"
        set -l commit_msg "$type: "(string replace -a '-' ' ' "$description")

        echo ""
        echo "📝 Creating branch: $branch_name"
        echo "💬 Commit message: $commit_msg"
        echo ""

        # Create new change with description
        if not command jj new -m "$commit_msg"
          echo "❌ Failed to create new change"
          return 1
        end

        # Create bookmark
        if not command jj bookmark create "$branch_name"
          echo "❌ Failed to create bookmark"
          return 1
        end

        # Push to remote
        echo ""
        echo "🚀 Pushing to remote..."
        if not command jj git push --branch "$branch_name"
          echo "❌ Failed to push to remote"
          return 1
        end

        echo ""
        echo "✅ Branch created and pushed successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Make your changes"
        echo "  2. Run 'jj describe' or 'jjdescribe' to update commit message"
        echo "  3. Run 'jjpush' to push and create PR (typically back to dev)"
        echo ""
      '';
    };

    jjpush = {
      description = "Push current branch and create PR with auto-merge";
      body = ''
        # Get current bookmark
        set -l bookmark (command jj bookmark list 2>/dev/null | grep '^\*' | awk '{print $2}')

        if test -z "$bookmark"
          echo "❌ No active bookmark found"
          echo "   Create a branch first with 'jjbranch'"
          return 1
        end

        # Push changes
        echo "🚀 Pushing changes..."
        if not command jj git push
          echo "❌ Failed to push changes"
          return 1
        end

        # Create PR with auto-merge label
        echo ""
        echo "📋 Creating pull request with auto-merge..."
        if not command gh pr create --fill --label auto-merge
          echo "❌ Failed to create PR"
          echo "   You may need to create it manually"
          return 1
        end

        echo ""
        echo "✅ Pull request created successfully!"
        echo ""
        echo "🔄 CI pipeline will run automatically"
        echo "✨ PR will auto-merge when all checks pass"
        echo ""
        echo "View PR status:"
        echo "  gh pr view --web"
        echo ""
      '';
    };

    jjb = {
      description = "Alias for jjbranch";
      body = ''
        jjbranch $argv
      '';
    };

    jjdescribe = {
      description = "Update commit description with AI-powered suggestion";
      body = ''
        echo "🤖 Generating commit message suggestion with lumen..."
        echo ""

        # Generate suggestion using lumen
        set -l suggestion (${inputs.self.packages.${pkgs.hostPlatform.system}.lumen}/bin/lumen draft 2>/dev/null)

        if test -z "$suggestion"
          echo "❌ Failed to generate suggestion"
          echo "   Falling back to manual describe"
          command jj describe
          return $status
        end

        # Display suggestion
        echo "💡 Suggested commit message:"
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
              echo "✅ Commit description updated"
            else
              echo "❌ Failed to update description"
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
                echo "✅ Commit description updated"
              else
                echo "❌ Failed to update description"
                return 1
              end
            else
              echo "❌ Empty message, aborting"
              return 1
            end

          case c C
            # Write custom message
            command jj describe

          case q Q
            echo "❌ Cancelled"
            return 0

          case '*'
            echo "❌ Invalid option"
            return 1
        end
      '';
    };
  };

  programs.fish.interactiveShellInit = ''
    # Completions for jj command
    complete -c jj -f -a "log diff commit sync search ui" -d "Jujutsu VCS subcommands"
    complete -c jj -s h -l help -d "Show help message"

    # Completions for workflow commands
    complete -c jjbranch -d "Create branch with conventional commit"
    complete -c jjb -d "Alias for jjbranch"
    complete -c jjpush -d "Push and create PR with auto-merge"
    complete -c jjdescribe -d "Update description with AI suggestion"

    # Add lazyjj alias for convenience
    alias jjui="lazyjj"
  '';
}
