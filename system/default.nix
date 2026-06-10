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

  # Server systems: no desktop graphics stack, no AMD GPU, no acpilight
  server = [
    ./core
    ./hardware/server.nix
    ./network.nix
  ];
in {
  inherit desktop laptop common server;
}
