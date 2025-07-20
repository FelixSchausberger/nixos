{pkgs, ...}: {
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
          echo "  jj edit <change>   - Edit specific change"
          echo "  jj branch          - Branch operations"
          echo "  jj sync            - Fetch and push"
          echo "  jj workspace       - Workspace operations"
          echo "  jj search          - Interactive file search"
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
          case edit e
            jj_edit $flags
          case branch b
            jj_branch $flags
          case sync
            jj_sync $flags
          case workspace ws
            jj_workspace $flags
          case search
            jj_search $flags
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

    jj_edit = {
      description = "Edit specific change";
      body = ''
        if test -z "$argv[1]"
          echo "Usage: jj edit <change-id>"
          return 1
        end
        command jj edit $argv
      '';
    };

    jj_branch = {
      description = "Branch operations";
      body = ''
        if test -z "$argv[1]"
          command jj branch list
        else
          command jj branch $argv
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

    jj_workspace = {
      description = "Workspace operations";
      body = ''
        if test -z "$argv[1]"
          command jj workspace list
        else
          command jj workspace $argv
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
  };

  programs.fish.interactiveShellInit = ''
    # Completions for jj command
    complete -c jj -f -a "log diff commit edit branch sync workspace search" -d "Jujutsu VCS subcommands"
    complete -c jj -s h -l help -d "Show help message"
  '';
}
