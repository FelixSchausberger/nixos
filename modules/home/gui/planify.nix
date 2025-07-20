{pkgs, ...}: {
  home.packages = with pkgs; [
    planify # Task manager with Todoist support
    noto-fonts-emoji-blob-bin # Needed for planify
  ];

  fonts.fontconfig.enable = true;
}
