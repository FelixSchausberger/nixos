{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    prusa-slicer
  ];

  home.activation.addToDialout = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! groups ${config.home.username} | grep -q '\bdialout\b'; then
      echo "Warning: You need to manually add ${config.home.username} to the dialout group."
    fi
    if [ -e /dev/ttyACM0 ]; then
      chmod a+rw /dev/ttyACM0 || echo "Error: Cannot change permissions for /dev/ttyACM0."
    fi
  '';
}
