{pkgs, ...}: {
  imports = [
    ./shells
    ./tui
  ];

  home.packages = with pkgs; [
    remmina # Remote desktop client written in GTK
    sqlite # Self-contained, serverless, zero-configuration, transactional SQL database engine
  ];
}
