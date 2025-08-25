{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./dprint.nix # Code formatting platform written in Rust
    ./languages.nix
  ];

  home.shellAliases = {
    hn = "hx /per/etc/nixos";
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    package = pkgs.helix;

    settings = {
      editor = {
        gutters = ["diff" "line-numbers" "spacer" "diagnostics"];
        cursorline = true;
        # cursor-shape = {
        #   normal = "block";
        #   insert = "bar";
        #   select = "underline";
        # };
        true-color = true;
        lsp.display-messages = true;
        mouse = false;
        shell = [
          "/etc/profiles/per-user/${config.home.username}/bin/fish"
          "-c"
        ];
        soft-wrap = {
          enable = true;
          wrap-indicator = "";
        };
      };
      theme = "base16_transparent";
      keys = {
        insert = {
          esc = ["collapse_selection" "normal_mode"];
        };

        normal = {
          esc = ["collapse_selection" "normal_mode"];
          X = "extend_line_above";
          a = ["append_mode" "collapse_selection"];
          g = {
            q = ":reflow";
            n = "goto_line_start";
            o = "goto_line_end";
          };
          ret = ["move_line_down" "goto_line_start"];
          space = {
            w = ":write";
            q = ":quit";
            space = "file_picker";
            W = ":lsp-workspace-command"; # LSP workspace commands
          };

          # Colemak-DH: hjkl -> neio
          n = "move_char_left";
          e = "move_line_down";
          i = "move_line_up";
          o = "move_char_right";

          h = ["insert_mode" "collapse_selection"];
          H = "insert_at_line_start";

          l = "open_below";
          L = "open_above";

          k = "move_next_word_end";
          K = "move_next_long_word_end";

          j = "search_next";
          J = "search_prev";
        };

        select = {
          esc = ["collapse_selection" "keep_primary_selection" "normal_mode"];

          # Colemak-DH: hjkl -> neio
          n = "move_char_left";
          e = "move_line_down";
          i = "move_line_up";
          o = "move_char_right";

          h = ["insert_mode" "collapse_selection"];
          H = "insert_at_line_start";

          l = "open_below";
          L = "open_above";

          k = "move_next_word_end";
          K = "move_next_long_word_end";

          j = "search_next";
          J = "search_prev";
        };
      };
    };
  };
}
