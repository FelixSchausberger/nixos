{
  inputs,
  pkgs,
  ...
}: let
  # Upstream still ships the functional entry as init.lua, while yazi loads
  # main.lua. Repackage it under the expected name instead of patching the
  # plugin input on every update.
  mountPlugin = pkgs.runCommand "mount.yazi" {} ''
    mkdir -p $out
    cp ${inputs.yazi-mount}/init.lua $out/main.lua
    cp ${inputs.yazi-mount}/LICENSE $out/LICENSE
  '';
in {
  programs.yazi = {
    plugins.mount.package = mountPlugin;

    keymap.mgr.prepend_keymap = [
      {
        on = ["M"];
        run = "plugin mount";
        desc = "Mount manager";
      }
    ];
  };

  home.packages = with pkgs; [
    mmtui # TUI disk mount manager for TUI file managers.
  ];
}
