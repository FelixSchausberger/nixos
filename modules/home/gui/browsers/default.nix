{...}: {
  imports = [
    ./ladybird.nix # Independent engine (LibWeb), alpha quality
    ./zen.nix # Open-source fork of Mozilla Firefox
  ];
}
