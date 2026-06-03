{...}: {
  imports = [
    ./niri.nix.specialisation
  ];

  wm.niri.outputs = [
    {
      # Keep physical outputs auto-detected and only disable the virtual stream output.
      name = "VIRTUAL-1";
      enable = false;
    }
  ];
}
