let
  desktop = [
    ./core
    ./hardware
    ./network.nix
    ./nix
  ];

  laptop =
    desktop;
in {
  inherit desktop laptop;
}
