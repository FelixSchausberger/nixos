let
  desktop = [
    ./core
    ./hardware
    ./network.nix
    ./nix
    # ./programs
  ];

  laptop =
    desktop;
in {
  inherit desktop laptop;
}
