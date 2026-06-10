{
  config,
  lib,
  ...
}: let
  sudoAbbrExclusions = [
    "pls"
    "nixinfo"
    "list-errors"
    "rip"
    "build"
  ];

  shellAbbrs = lib.mapAttrs (_n: v: {
    position = "anywhere";
    command = [
      "sudo"
      "pls"
    ];
    expansion = v;
  }) (lib.filterAttrs (n: _: !lib.elem n sudoAbbrExclusions) config.home.shellAliases);
in {
  imports = [
    ./bash.nix
    ./fish
    ./bat.nix
    ./direnv.nix
    ./eza.nix
    ./fzf.nix
    ./starship.nix
    ./zoxide.nix
  ];

  home.shellAliases = {
    bios = "systemctl reboot --firmware-setup";
    build = "nix build -L";
    cp = "cp -rpv";
    list-errors = "journalctl -p err -b --output=cat | sort | uniq -c | sort -nr";
    merge = "rsync -avhu --info=progress2 --partial --append-verify";
    nixinfo = "nix-shell -p nix-info --run 'nix-info -m'";
    pls = "sudo";
    repair = "nix-store --verify --check-contents --repair";
    rip = "rip --graveyard /per/home/${config.home.username}/.local/share/graveyard";
    rsync = "rsync -avhP --no-inc-recursive";
  };

  programs.fish.shellAbbrs = shellAbbrs;
}
