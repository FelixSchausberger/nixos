{
  programs.zoxide = {
    enable = true;

    enableBashIntegration = true;
    enableFishIntegration = true;

    options = [
      "--cmd cd" # Replace 'cd' command with zoxide
    ];
  };
}
