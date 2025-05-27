# home/private/tui/default.nix
{
  imports = [
    ../../../modules/home/tui/git.nix # Base shared Git module
    ./private-git-features.nix        # Private Git additions
    ./typix.nix
  ];
}
