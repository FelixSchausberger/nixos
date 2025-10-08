{
  # No additional function imports needed - using simple shell aliases and inline functions instead

  programs.fish.functions = {
    fish_prompt = {
      description = "Custom fish prompt";
      body = ''
        set -l nix_shell_info ""
        if test -n "$IN_NIX_SHELL"
          set nix_shell_info "<nix-shell> "
        end

        # Jujutsu (JJ) prompt integration (Fish 4.1.0+)
        set -l jj_prompt_info ""
        if command -v jj >/dev/null 2>&1; and test -d .jj
          set jj_prompt_info (fish_jj_prompt 2>/dev/null)
          if test -n "$jj_prompt_info"
            set jj_prompt_info "$jj_prompt_info "
          end
        end

        set_color $fish_color_cwd
        echo -n (prompt_pwd)
        set_color normal
        echo -n -s " $nix_shell_info$jj_prompt_info~> "
      '';
    };
  };
}
