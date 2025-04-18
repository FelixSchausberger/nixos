{
  programs.fzf = {
    enable = true;
    defaultCommand = "fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--info=inline"
      "--border"
      "--margin=1"
      "--padding=1"
    ];
    enableFishIntegration = false;
  };
}
