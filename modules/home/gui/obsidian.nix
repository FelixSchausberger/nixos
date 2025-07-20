{
  # config,
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    inputs.self.packages.${pkgs.system}.basalt # TUI Application to manage Obsidian notes directly from the terminal
    obsidian
  ];
}
