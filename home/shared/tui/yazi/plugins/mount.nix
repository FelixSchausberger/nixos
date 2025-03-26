{
  inputs,
  pkgs,
  ...
}: {
  home.file.".config/yazi/plugins/mount" = {
    source = inputs.yazi-mount;
    recursive = true;
  };

  programs.yazi = {
    keymap.manager.prepend_keymap = [
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
