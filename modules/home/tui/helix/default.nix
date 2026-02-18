{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./dprint.nix # Code formatting platform written in Rust
    ./languages-core.nix
    ./languages-extended.nix
  ];

  home.shellAliases = {
    hn = "hx /per/etc/nixos";
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    # Temporarily using upstream helix due to helix-steel build issues
    # To restore Steel plugin support, uncomment the line below and comment the pkgs.helix line
    # package = pkgs.helix-steel;
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
      theme = lib.mkDefault "catppuccin_mocha";
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

  # home.sessionVariables.STEEL_COGS = ''
  #   $HOME/.local/share/steel/cogs:${pkgs.scooter-hx}/lib/helix-plugins/scooter:${pkgs.helix-steel}/share/steel/cogs
  # '';

  # Steel plugin system disabled - helix-steel build currently broken
  # Uncomment this section when helix-steel builds successfully again
  #
  # To re-enable:
  # 1. Uncomment the entire Steel plugin configuration block below
  # 2. Change package = pkgs.helix; to package = pkgs.helix-steel; (line 23)
  # 3. Rebuild with: sudo nixos-rebuild switch --flake .

  # # Steel plugin system configuration
  # home.file.".config/helix/init.scm".text = ''
  #   ;; Helix Steel initialization
  #   ;; Load scooter plugin
  #   (require "scooter/scooter.scm")
  # '';
  #
  # # Symlink scooter plugin files to Steel's cogs directory
  # home.file.".steel/cogs/scooter" = {
  #   source = "${pkgs.scooter-hx}/lib/helix-plugins/scooter";
  #   recursive = true;
  # };
  #
  # home.file.".steel/cogs/ui" = {
  #   source = "${pkgs.scooter-hx}/lib/helix-plugins/ui";
  #   recursive = true;
  # };
  #
  # # Create writable helix cogs directory (Helix generates modules here)
  # home.file.".steel/cogs/helix/.keep".text = "";
  #
  # # Copy dylib to Steel's native library directory
  # # Steel searches for dylibs in ~/.steel/native/
  # home.file.".steel/native/libscooter_hx.so" = {
  #   source = "${pkgs.scooter-hx}/lib/helix-plugins/scooter/libscooter_hx.so";
  # };
}
