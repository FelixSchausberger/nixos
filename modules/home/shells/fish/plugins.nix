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
        inherit (pkgs.fishPlugins.done) src;
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
