{
  # config,
  # inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    grc # A generic text colouriser
  ];

  programs.bash = {
    enable = true;

    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      COMPLETE=fish jj | source
    '';
    # direnv hook fish | source

    plugins = [
      # {
      #   # Make your prompt asynchronous to improve the reactivity
      #   name = "async-prompt";
      #   src = pkgs.fishPlugins.async-prompt.src;
      # }
      {
        # Auto-complete matching pairs in the Fish command line
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
      {
        # Fish function making it easy to use utilities written for Bash in Fish shell
        name = "bass";
        src = pkgs.fishPlugins.bass.src;
      }
      {
        # Automatically receive notifications when long processes finish
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      {
        # Fish plugin that reminds you to use your aliases
        name = "fish-you-should-use";
        src = pkgs.fishPlugins.fish-you-should-use.src;
      }
      {
        # Augment your fish command line with fzf key bindings
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        # grc Colourizer for some commands on Fish shell
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      {
        # Fish plugin to quickly put 'sudo' in your command
        name = "plugins-sudope";
        src = pkgs.fishPlugins.plugin-sudope.src;
      }
      {
        # Text Expansions for Fish
        name = "puffer";
        src = pkgs.fishPlugins.puffer.src;
      }
      {
        # Pure-fish z directory jumping
        name = "z";
        src = pkgs.fishPlugins.z.src;
      }
    ];
  };

  xdg.configFile."fish/functions/fish_prompt.fish".text = ''
    function fish_prompt
      set -l nix_shell_info (
          if test -n "$IN_NIX_SHELL"
              echo -n "<nix-shell> "
          end
      )

      set_color $fish_color_cwd
      echo -n (prompt_pwd)
      set_color normal
      echo -n -s " $nix_shell_info ~>"
    end
  '';
}
