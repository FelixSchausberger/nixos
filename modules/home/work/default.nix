{pkgs, ...}: {
  imports = [
    ./shells
    ./tui
  ];

  home.packages = with pkgs; [
    teams-for-linux # Unofficial Microsoft Teams client for Linux
  ];
}
