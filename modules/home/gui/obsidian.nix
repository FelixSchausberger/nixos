{
  # config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    basalt # TUI Application to manage Obsidian notes directly from the terminal
    obsidian
  ];
}
