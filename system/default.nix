let
  # Common modules shared across all systems
  common = [
    ./core
    ./hardware
    ./network.nix
  ];

  # Desktop systems (includes common modules)
  desktop = common;

  # Laptop systems (same as desktop for now, but allows future differentiation)
  laptop = common;
in {
  inherit desktop laptop common;
}
