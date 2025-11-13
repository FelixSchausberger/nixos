{pkgs, ...}: {
  programs.fish = {
    enable = true;
    plugins = [
      # {
      #   # Make your prompt asynchronous to improve the reactivity
      #   name = "async-prompt";
      #   src = pkgs.fishPlugins.async-prompt.src;
      # }
      {
        # Auto-complete matching pairs in the Fish command line
        name = "autopair";
        inherit (pkgs.fishPlugins.autopair) src;
      }
      {
        # Fish function making it easy to use utilities written for Bash in Fish shell
        name = "bass";
        inherit (pkgs.fishPlugins.bass) src;
      }
      {
        # Automatically receive notifications when long processes finish
        name = "done";
        # Use source directly and patch it, rather than overrideAttrs which rebuilds
        # with buildFishPlugin (changing directory structure)
        src =
          pkgs.runCommand "fishplugin-done-patched" {
            inherit (pkgs.fishPlugins.done) src;
            nativeBuildInputs = [pkgs.perl];
          } ''
                                  cp -r $src $out
                                  chmod -R +w $out
                                  # Fix plugin to check for wslpath before using it
                                  sed -i 's|and command --search wslvar$|and command --search wslvar\n        and command --search wslpath|' $out/conf.d/done.fish
                                  # Add fallback to absolute path if wslvar/wslpath fail
                                  perl -0pi -e 's|    if string length --quiet "\$powershell_exe"|    if not string length --quiet "\$powershell_exe"\n        and test -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe\n        set -l powershell_exe /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe\n    end\n\n    if string length --quiet "\$powershell_exe"|g' $out/conf.d/done.fish

                                  # Enhance notification messages to show more context
                                  # Change success title to include exit status
                                  sed -i 's|set -l title "Done in \$humanized_duration"|set -l title "Command completed in \$humanized_duration (exit \$exit_status)"|' $out/conf.d/done.fish
                                  # Change failure title to be more explicit
                                  sed -i 's|set title "Failed (\$exit_status) after \$humanized_duration"|set title "Command failed (exit \$exit_status) after \$humanized_duration"|' $out/conf.d/done.fish
                                  # Enhance message to include timestamp
                                  sed -i 's|set -l message "\$wd/ \$argv\[1\]"|set -l timestamp (date +"%H:%M:%S")\n            set -l message "\$argv[1]\\n\$wd • \$timestamp"|' $out/conf.d/done.fish

                                  # Add Zellij pane activity detection function after screen function
                                  # The screen function is just one line: string match --quiet --regex "$STY\s+\(Attached" (screen -ls)
                                  # We need to add our function after the "end" that closes the screen function
                                  sed -i '/^function __done_is_screen_window_active$/,/^end$/{
                                    /^end$/a\
                        \
                        function __done_is_zellij_pane_active\
                            # Check if current Zellij pane is focused\
                            # Returns 0 (true) if pane is active, 1 (false) otherwise\
                            set -q ZELLIJ_PANE_ID; or return 1\
                        \
                            # Get the focused pane ID from Zellij layout dump\
                            set -l focused_pane_id (zellij action dump-layout 2>/dev/null | grep -A 1 "focus=true" | grep -o "pane_id=\\"[0-9]*\\"" | head -1 | grep -o "[0-9]*")\
                        \
                            # Compare with current pane ID\
                            test "$ZELLIJ_PANE_ID" = "$focused_pane_id"\
                        end
                                  }' $out/conf.d/done.fish

                                  # Modify focus detection to check Zellij panes
                                  # Add Zellij check alongside TMUX check in __done_is_process_window_focused
                                  sed -i '/# If inside a tmux session, check if the tmux window is focused/i\
                            # If inside a Zellij session, check if the Zellij pane is focused\
                            if type -q zellij\
                                and test -n "$ZELLIJ"\
                                __done_is_zellij_pane_active\
                                return $status\
                            end\
                        \
                        ' $out/conf.d/done.fish

                                  # Fix __done_allow_nongraphical behavior
                                  # The original returns 1 (focused) which prevents notifications
                                  # We need it to return 0 (not focused) to always trigger notifications in nongraphical mode
                                  sed -i 's|if set -q __done_allow_nongraphical|if set -q __done_allow_nongraphical_disabled_by_patch|' $out/conf.d/done.fish
                                  # Add correct nongraphical check at the start of the function
                                  sed -i '/^function __done_is_process_window_focused$/a\
                # In nongraphical mode, always consider window as unfocused (return 0) to trigger notifications\
                if set -q __done_allow_nongraphical\
                    return 0\
                end\
            ' $out/conf.d/done.fish

          '';
      }
      {
        # Fish plugin that reminds you to use your aliases
        name = "fish-you-should-use";
        inherit (pkgs.fishPlugins.fish-you-should-use) src;
      }
      {
        # Augment your fish command line with fzf key bindings
        name = "fzf-fish";
        inherit (pkgs.fishPlugins.fzf-fish) src;
      }
      {
        # grc Colouriser for some commands on Fish shell
        name = "grc";
        inherit (pkgs.fishPlugins.grc) src;
      }
      {
        # Fish plugin to quickly put 'sudo' in your command
        name = "plugins-sudope";
        inherit (pkgs.fishPlugins.plugin-sudope) src;
      }
      {
        # Text Expansions for Fish
        name = "puffer";
        inherit (pkgs.fishPlugins.puffer) src;
      }
      {
        # Pure-fish z directory jumping
        name = "z";
        inherit (pkgs.fishPlugins.z) src;
      }
    ];
  };
}
