{
  programs.yazi.theme.filetype.rules = builtins.fromJSON (builtins.readFile ./filetype.json);
}
