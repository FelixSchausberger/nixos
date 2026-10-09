{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  c = inputs.self.lib.catppuccinColors.mocha;

  # TTT ships no Home Manager module; the flake's default package is the
  # editor binary.
  ttt = inputs.ttt.packages.${system}.default;

  # TTT runs one language server per file extension, chosen by extension,
  # while Helix and Neovim run every server listed for a language. This
  # derives a deterministic server per language (the first) and a single
  # extension map from the same shared data (editors.languages), so TTT speaks
  # to the same servers as the other editors. lsp-ai and jj-lsp are skipped:
  # neither is a conventional LSP server, and lsp-ai would otherwise be picked
  # as the Nix handler.
  excludedLspServers = ["lsp-ai" "jj-lsp"];

  tttLspServers =
    lib.foldl' (
      acc: lang: let
        server = builtins.head lang.servers;
      in
        if lang.servers == [] || builtins.elem server excludedLspServers
        then acc
        else
          acc
          // {
            ${server} = {
              command = config.editors.languageServers.${server}.cmd;
              languages =
                (acc.${server}.languages or {})
                // lib.genAttrs (map (ft: ".${ft}") lang.fileTypes) (_: lang.name);
            };
          }
    ) {}
    config.editors.languages;

  # External formatters read the buffer from stdin and write the result to
  # stdout, which is exactly the shape the shared data records, so the command
  # translates directly to TTT's formatter string.
  formatterCommand = fmt: lib.concatStringsSep " " ([fmt.command] ++ fmt.args);

  tttFormatters =
    lib.foldl' (
      acc: lang:
        if lang.formatter == null
        then acc
        else lib.foldl' (a: ft: a // {${ft} = formatterCommand lang.formatter;}) acc lang.fileTypes
    ) {}
    config.editors.languages;

  # markdown-preview renders prose in a tab; the vim plugin (API 2, supported
  # by this build) restores modal editing. Keys are the plugin names TTT loads;
  # the manifests are read below for the registry seed.
  tttPluginSources = {
    vim = inputs."ttt-vim";
    markdown-preview = inputs."ttt-plugins" + "/markdown-preview";
  };

  # TTT lists ~/.config/ttt/plugins with os.ReadDir, whose IsDir reports the
  # symlink itself rather than its target, so a symlinked plugin directory is
  # skipped. The bundle therefore copies each plugin into real directories at
  # the store root; the only symlink is the plugins directory itself, which
  # ReadDir opens and follows.
  tttPlugins = pkgs.runCommand "ttt-plugins" {} (
    "mkdir -p $out\n"
    + lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: "cp -r ${src} $out/${name}") tttPluginSources)
  );

  # TTT stores plugin enablement and granted permissions in plugins.ttt.json,
  # a mutable file it rewrites. Seed it once from the manifests so the pinned
  # first-party plugins load without an interactive approval dialog on a
  # headless or remote first run; TTT owns the file afterwards and re-asks if
  # a plugin later requests new permissions.
  tttRegistry = builtins.toJSON (lib.mapAttrsToList (_: src: let
      manifest = builtins.fromJSON (builtins.readFile (src + "/plugin.ttt.json"));
    in {
      inherit (manifest) name version permissions;
      enabled = true;
    })
    tttPluginSources);

  tttRegistryFile = pkgs.writeText "ttt-plugins.ttt.json" tttRegistry;

  # TTT has no built-in Catppuccin theme, so it is generated from the fleet
  # palette (the same source as Zellij and Stylix). The filename minus .json is
  # the theme name settings.theme selects. Unset fields resolve from these
  # values, so only the sections TTT needs are written.
  theme = {
    default = {
      fg = c.text;
      bg = c.base;
    };
    muted = {fg = c.overlay1;};
    success = {fg = c.green;};
    danger = {fg = c.red;};
    warning = {fg = c.yellow;};
    border = {fg = c.surface1;};
    statusBar = {fg = c.text;};
    tabs = {
      active = {
        fg = c.text;
        bg = c.mantle;
        bold = true;
      };
      inactive = {fg = c.overlay1;};
      selected = {
        fg = c.text;
        bg = c.surface0;
      };
    };
    sidebar = {
      header = {
        fg = c.text;
        bold = true;
      };
      item = {fg = c.subtext1;};
      selected = {
        fg = c.text;
        bg = c.surface0;
      };
    };
    dialog = {
      input = {};
      item = {fg = c.subtext1;};
      selected = {
        fg = c.text;
        bg = c.surface0;
      };
      muted = {fg = c.overlay1;};
    };
    editor = {
      lineNumber = {fg = c.surface2;};
      activeLine = {bg = c.mantle;};
      selection = {bg = c.surface1;};
      searchMatch = {
        fg = c.base;
        bg = c.yellow;
      };
      searchActive = {
        fg = c.base;
        bg = c.peach;
      };
      bracketMatch = {bg = c.surface1;};
      diagnostics = {
        error = {fg = c.red;};
        warning = {fg = c.yellow;};
        info = {fg = c.sky;};
        hint = {fg = c.overlay1;};
      };
    };
    menu = {
      item = {fg = c.subtext1;};
      active = {
        fg = c.text;
        bg = c.surface0;
        bold = true;
      };
    };
    hover = {
      bold = {
        fg = c.text;
        bold = true;
      };
      italic = {
        fg = c.text;
        italic = true;
      };
      code = {fg = c.green;};
    };
    scrollbar = {
      fg = c.overlay0;
      bg = c.surface0;
    };
    syntax = {
      comment = {
        fg = c.overlay1;
        italic = true;
      };
      string = {fg = c.green;};
      keyword = {fg = c.mauve;};
      number = {fg = c.peach;};
      operator = {fg = c.sky;};
      function = {fg = c.blue;};
      type = {fg = c.yellow;};
      builtin = {fg = c.yellow;};
      variable = {fg = c.text;};
      punctuation = {fg = c.overlay2;};
      tag = {fg = c.mauve;};
      attribute = {fg = c.yellow;};
      regexp = {fg = c.pink;};
      heading = {
        fg = c.blue;
        bold = true;
      };
      bold = {
        fg = c.text;
        bold = true;
      };
      italic = {
        fg = c.text;
        italic = true;
      };
      quote = {fg = c.overlay1;};
      inserted = {fg = c.green;};
      deleted = {fg = c.red;};
      invalid = {fg = c.red;};
      control = {fg = c.mauve;};
      storage = {fg = c.mauve;};
      constant = {fg = c.peach;};
      escape = {fg = c.pink;};
      parameter = {fg = c.maroon;};
      property = {fg = c.lavender;};
      self = {fg = c.red;};
      namespace = {fg = c.yellow;};
      decorator = {fg = c.peach;};
      link = {fg = c.sapphire;};
      code = {fg = c.green;};
    };
    terminal = {
      foreground = c.text;
      background = c.base;
      black = c.surface1;
      inherit (c) red;
      inherit (c) green;
      inherit (c) yellow;
      inherit (c) blue;
      magenta = c.mauve;
      cyan = c.teal;
      white = c.subtext1;
      brightBlack = c.surface2;
      brightRed = c.red;
      brightGreen = c.green;
      brightYellow = c.yellow;
      brightBlue = c.blue;
      brightMagenta = c.pink;
      brightCyan = c.sky;
      brightWhite = c.text;
    };
    borders = {
      horizontal = "─";
      vertical = "│";
      topLeft = "╭";
      topRight = "╮";
      bottomLeft = "╰";
      bottomRight = "╯";
      topTee = "┬";
      bottomTee = "┴";
      leftTee = "├";
      rightTee = "┤";
    };
  };

  settings = {
    version = 1;
    theme = "catppuccin-mocha";
    appearance.icons = "nerd-font";
    editor = {
      # 2-space is the fleet's Nix/Rust convention; TTT also detects indentation
      # per file, so this is only the fallback.
      tabSize = 2;
      insertSpaces = true;
      wordWrap = false;
      formatOnSave = true;
      lineNumbers = true;
      cursorStyle = "block";
      bracketPairColorization = true;
      gitGutter = true;
      focusOnOpen = true;
    };
    explorer = {
      showHidden = true;
      # Hide gitignored files: the NixOS repo tree is unusable with result/
      # symlinks and ignored build output in the explorer.
      showGitIgnored = false;
      gitStatusColors = true;
      autoReveal = true;
    };
    terminal = {
      shell = "${pkgs.fish}/bin/fish";
      scrollback = 5000;
    };
    lsp = {
      servers = tttLspServers;
      saveOnRename = false;
    };
    formatters = tttFormatters;
    markdown.wrapWidth = 100;
  };
in {
  home.packages = [ttt];

  # settings.json is the declarative source; TTT's in-app Settings editor
  # writes this file and therefore cannot persist under Home Manager. Edit the
  # module instead.
  xdg.configFile = {
    "ttt/settings.json".text = builtins.toJSON settings;
    "ttt/themes/catppuccin-mocha.json".text = builtins.toJSON theme;
    "ttt/plugins".source = tttPlugins;
  };

  # Seed the plugin registry only when absent: TTT rewrites this file when a
  # plugin is toggled or re-approved, and a Home Manager symlink would make
  # those writes fail.
  home.activation.seedTttPluginRegistry = lib.hm.dag.entryAfter ["writeBoundary"] ''
    registry="$HOME/.config/ttt/plugins.ttt.json"
    if [ ! -e "$registry" ]; then
      ${pkgs.coreutils}/bin/install -D -m 0644 ${tttRegistryFile} "$registry"
    fi
  '';
}
