{
  programs.fish.functions = {
    pull = {
      description = "Smart pull: jj git fetch in jj repo, git pull otherwise";
      body = ''
        if jj root &>/dev/null
          command jj git fetch $argv
        else
          command git pull $argv
        end
      '';
    };

    push = {
      description = "Smart push: jj git push in jj repo, git push otherwise";
      body = ''
        if jj root &>/dev/null
          command jj git push $argv
        else
          command git push $argv
        end
      '';
    };

    fetch = {
      description = "Smart fetch: jj git fetch in jj repo, git fetch otherwise";
      body = ''
        if jj root &>/dev/null
          command jj git fetch $argv
        else
          command git fetch $argv
        end
      '';
    };

    amend = {
      description = "Smart amend: jj squash in jj repo, git commit --amend otherwise";
      body = ''
        if jj root &>/dev/null
          command jj squash $argv
        else
          command git commit --amend $argv
        end
      '';
    };

    rebase = {
      description = "Smart rebase: jj rebase in jj repo, git rebase -i otherwise";
      body = ''
        if jj root &>/dev/null
          command jj rebase $argv
        else
          command git rebase -i $argv
        end
      '';
    };

    log = {
      description = "Smart log: jj log in jj repo, git log otherwise";
      body = ''
        if jj root &>/dev/null
          command jj log $argv
        else
          command git log --graph --abbrev-commit --all $argv
        end
      '';
    };

    show = {
      description = "Smart show: jj show in jj repo, git show otherwise";
      body = ''
        if jj root &>/dev/null
          command jj show $argv
        else
          command git show $argv
        end
      '';
    };

    gst = {
      description = "Smart status: jj status in jj repo, git status otherwise";
      body = ''
        if jj root &>/dev/null
          command jj status $argv
        else
          command git status $argv
        end
      '';
    };

    undo = {
      description = "Smart undo: jj undo in jj repo, git reset --soft HEAD~1 otherwise";
      body = ''
        if jj root &>/dev/null
          command jj undo $argv
        else
          command git reset --soft HEAD~1 $argv
        end
      '';
    };

    redo = {
      description = "Smart redo: jj op restore in jj repo, git reset --hard HEAD@{1} otherwise";
      body = ''
        if jj root &>/dev/null
          command jj op restore $argv
        else
          command git reset --hard HEAD@{1} $argv
        end
      '';
    };

    main = {
      description = "Smart main: jj edit main in jj repo, git checkout main otherwise";
      body = ''
        if jj root &>/dev/null
          command jj edit main $argv
        else
          command git checkout main $argv
        end
      '';
    };

    master = {
      description = "Smart master: jj edit master in jj repo, git checkout master otherwise";
      body = ''
        if jj root &>/dev/null
          command jj edit master $argv
        else
          command git checkout master $argv
        end
      '';
    };

    gcm = {
      description = "Smart gcm: jj commit -m in jj repo, git commit -m otherwise";
      body = ''
        if jj root &>/dev/null
          command jj commit -m $argv
        else
          command git commit -m $argv
        end
      '';
    };

    clone = {
      description = "Smart clone: jj git clone in jj repo, git clone otherwise";
      body = ''
        if jj root &>/dev/null
          command jj git clone $argv
        else
          command git clone $argv
        end
      '';
    };

    ragequit = {
      description = "Smart ragequit: jj-aware wip commit and shutdown in jj repo, git commit -am wip && shutdown otherwise";
      body = ''
        if jj root &>/dev/null
          command jj describe -m wip
          and command jj new
          and shutdown -h now
        else
          git commit -am wip
          and shutdown -h now
        end
      '';
    };
  };

  programs.fish.interactiveShellInit = ''
    # Completions for vcs-aliased commands
    complete -c pull -f -a "origin" -d "Remote name"
    complete -c push -f -a "origin" -d "Remote name"
    complete -c fetch -f -a "origin" -d "Remote name"
    complete -c amend -s a -l all -d "Amend all"
    complete -c amend -s m -l message -d "Message" -r
    complete -c rebase -f -a "HEAD~" -d "Upstream"
    complete -c log -s n -l max-count -d "Limit" -r
    complete -c log -s p -l patch -d "Show patch"
    complete -c show -s s -l stat -d "Show stat"
    complete -c gst -s s -l short -d "Short format"
    complete -c gcm -s m -l message -d "Message" -r
  '';
}
