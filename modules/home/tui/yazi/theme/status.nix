{lib, ...}: {
  programs.yazi.theme.status = {
    separator_open = "";
    separator_close = "";
    separator_style = {
      fg = lib.mkDefault "darkgray";
      bg = lib.mkDefault "darkgray";
    };

    # Mode;
    mode_normal = {
      fg = lib.mkDefault "black";
      bg = lib.mkDefault "lightblue";
      bold = true;
    };
    mode_select = {
      fg = lib.mkDefault "black";
      bg = lib.mkDefault "lightgreen";
      bold = true;
    };
    mode_unset = {
      fg = lib.mkDefault "black";
      bg = lib.mkDefault "lightmagenta";
      bold = true;
    };

    # Progress;
    progress_label = {bold = true;};
    progress_normal = {
      fg = lib.mkDefault "blue";
      bg = lib.mkDefault "black";
    };
    progress_error = {
      fg = lib.mkDefault "red";
      bg = lib.mkDefault "black";
    };

    # Permissions;
    permissions_t = {fg = lib.mkDefault "blue";};
    permissions_r = {fg = lib.mkDefault "lightyellow";};
    permissions_w = {fg = lib.mkDefault "lightred";};
    permissions_x = {fg = lib.mkDefault "lightgreen";};
    permissions_s = {fg = lib.mkDefault "darkgray";};
  };
}
