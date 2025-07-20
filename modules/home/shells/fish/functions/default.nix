{
  imports = [
    ./nx.nix
  ];

  programs.fish.functions = {
    fish_prompt = {
      description = "Custom fish prompt";
      body = ''
        set -l nix_shell_info ""
        if test -n "$IN_NIX_SHELL"
          set nix_shell_info "<nix-shell> "
        end

        set_color $fish_color_cwd
        echo -n (prompt_pwd)
        set_color normal
        echo -n -s " $nix_shell_info ~> "
      '';
    };
  };
}
