{
  programs.fzf = {
    enable = true;

    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--info=inline"
      "--border"
      "--margin=1"
      "--padding=1"
      "--bind=ctrl-u:page-up,ctrl-d:page-down"
      "--preview='bat --color=always --style=numbers --line-range=:500 {}'"
      # Opens fzf as a floating pane in Zellij (or tmux); no-op outside multiplexers
      "--popup"
    ];

    enableBashIntegration = true;
    enableFishIntegration = true;
  };
}
