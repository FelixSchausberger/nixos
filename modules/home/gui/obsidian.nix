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

  # home.persistence."/per/home/${config.home.username}" = {
  #   directories = [
  #     {
  #       directory = ".config/obsidian";
  #       method = "symlink";
  #     }
  #   ];
  #   allowOther = true; #  Requires programs.fuse.userAllowOther to be enabled
  # };
}
