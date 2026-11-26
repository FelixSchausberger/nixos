{
  config,
  lib,
  pkgs,
  ...
}: let
  enabled = lib.elem "3d" config.features.creative.tools;
in {
  home.packages = lib.mkIf enabled (with pkgs; [
    prusa-slicer
  ]);

  home.activation.addToDialout = lib.mkIf enabled (lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! groups ${config.home.username} | grep -q '\bdialout\b'; then
      echo "Warning: You need to manually add ${config.home.username} to the dialout group."
    fi
    if [ -e /dev/ttyACM0 ]; then
      chmod a+rw /dev/ttyACM0 || echo "Error: Cannot change permissions for /dev/ttyACM0."
    fi
  '');
}
