{
  config,
  inputs,
  ...
}: {
  imports = [
    inputs.nhx.homeManagerModules.nhx # Declarative Helix config with Steel plugin support
    ./dprint.nix # Code formatting platform written in Rust
    ./languages-core.nix
    ./languages-extended.nix
  ];

  home.shellAliases = {
    hn = "hx /per/etc/nixos";
  };

  # nhx does not provide programs.helix.defaultEditor; replicate its effect.
  # STEEL_HOME must match nhx's cog link target (~/.local/share/steel): steel
  # would otherwise prefer an existing ~/.steel directory and never find the
  # declaratively installed cogs.
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    STEEL_HOME = "${config.home.homeDirectory}/.local/share/steel";
  };

  programs.nhx = {
    enable = true;
    # Uses pkgs.steelix by default (Helix fork with Steel plugin support)

    settings = {
      editor = {
        gutters = ["diff" "line-numbers" "spacer" "diagnostics"];
        cursorline = true;
        # cursor-shape = {
        #   normal = "block";
        #   insert = "bar";
        #   select = "underline";
        # };
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
      # nhx.settings is types.attrs, so mkDefault would leak the raw override
      # object into the TOML ([theme] table). Use a plain value.
      theme = "catppuccin_mocha";
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
            c = ":sh cargo check";
            b = ":sh cargo build";
            r = ":sh cargo run";
            t = ":sh cargo test";
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

    steel.enable = true;

    # Plugin derivations are symlinked into $STEEL_HOME/cogs by nhx.
    # Set enable = true to also add the (require ...) to init.scm.
    plugins = {
      scooter.enable = true;
      juju.enable = true;
      notify.enable = true;
      breadcrumbs.enable = true;
      steel-pty = {
        enable = true;
        # Entrypoint is term.scm, not the default steel-pty/steel-pty.scm
        requirePath = "steel-pty/term.scm";
      };
    };
  };
}
