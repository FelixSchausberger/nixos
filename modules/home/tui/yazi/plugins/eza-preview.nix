{
  inputs,
  pkgs,
  ...
}: {
  programs.yazi = {
    plugins.eza-preview = {
      package = "${inputs.yazi-eza-preview}";
      setup = true;
      settings = {
        default_tree = true;
        level = 3;
        icons = true;
        follow_symlinks = true;
        git_ignore = true;
      };
    };

    # A directory previewer only runs when it is registered; installing the
    # plugin alone leaves the built-in folder preview in place.
    settings.plugin.prepend_previewers = [
      {
        url = "*/";
        run = "eza-preview";
      }
    ];

    keymap.mgr.prepend_keymap = [
      {
        on = ["e" "t"];
        run = "plugin eza-preview";
        desc = "Toggle tree/list directory preview";
      }
      {
        on = ["e" "-"];
        run = "plugin eza-preview inc-level";
        desc = "Increase eza tree depth";
      }
      {
        on = ["e" "_"];
        run = "plugin eza-preview dec-level";
        desc = "Decrease eza tree depth";
      }
    ];

    extraPackages = [pkgs.eza];
  };
}
