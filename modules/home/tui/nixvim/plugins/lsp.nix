{
  config,
  lib,
  ...
}: let
  inherit (config.editors) languages languageServers;

  # HM host modules get nixvim's helpers from config.lib; the lib module arg
  # is plain Nixpkgs lib without the nixvim extension.
  inherit (config.lib.nixvim) mkRaw;

  # Helix server name -> nvim-lspconfig config name. nvim-lspconfig ships root
  # markers, filetypes, and defaults under its own names; the shared cmd and
  # init_options are passed to vim.lsp.config(), whose values take precedence
  # over the runtime lsp/*.lua files. Servers without an lspconfig config keep
  # the shared name and get explicit root markers instead.
  lspconfigNames = {
    "bash-language-server" = "bashls";
    "yaml-language-server" = "yamlls";
    "vscode-json-language-server" = "jsonls";
    "vscode-html-language-server" = "html";
    "vscode-css-language-server" = "cssls";
    "typescript-language-server" = "ts_ls";
    "lua-language-server" = "lua_ls";
    "docker-langserver" = "dockerls";
    "docker-compose-langserver" = "docker_compose_language_service";
    "fish-lsp" = "fish_lsp";
    "markdown-oxide" = "markdown_oxide";
  };

  # Root markers for the two servers nvim-lspconfig has no default config for.
  rootMarkers = {
    lsp-ai = [".git"];
    jj-lsp = [
      ".jj"
      ".git"
    ];
  };

  # Neovim filetypes per server, inverted from the per-language lists so both
  # editors serve the same files from one source.
  filetypesFor = server:
    lib.unique (lib.concatMap (lang: lang.filetypes) (lib.filter (lang: lib.elem server lang.servers) languages));

  # rust-analyzer is deliberately absent: rustaceanvim starts its own client
  # and nixvim forbids enabling both. Servers no language references (e.g.
  # docker-compose-langserver) stay disabled too: Helix only attaches servers
  # listed per language, so enabling them here would spawn LSPs Helix never
  # starts, from packages the development gate may not install.
  mkServer = name: server:
    if name == "rust-analyzer" || filetypesFor name == []
    then {}
    else {
      enable = true;
      # Server binaries come from the shared, feature-gated home.packages set;
      # package = null keeps nixvim from putting a second copy on nvim's PATH.
      package = null;
      config =
        {inherit (server) cmd;}
        // lib.optionalAttrs (filetypesFor name != []) {filetypes = filetypesFor name;}
        // lib.optionalAttrs (server.config != {}) {init_options = server.config;}
        // lib.optionalAttrs (rootMarkers ? ${name}) {root_markers = rootMarkers.${name};};
    };
in {
  programs.nixvim = {
    # lspconfig's lsp/*.lua files provide root markers and defaults that the
    # explicit config above merges over.
    plugins.lspconfig.enable = true;

    # Render diagnostics inline with a readable float, sorted worst-first.
    diagnostic.settings = {
      severity_sort = true;
      virtual_text = {
        spacing = 2;
        source = "if_many";
      };
      float.border = "rounded";
    };

    lsp = {
      # vim.lsp.inlay_hint.enable(true): inline parameter and return-type hints.
      inlayHints.enable = true;

      # Bindings beyond Neovim's own (K, gd, gD, gi, gr are set per buffer on
      # attach by Neovim itself; descriptions show up in which-key either way).
      keymaps = [
        {
          mode = "n";
          key = "gd";
          lspBufAction = "definition";
          options.desc = "LSP: definition";
        }
        {
          mode = "n";
          key = "gD";
          lspBufAction = "declaration";
          options.desc = "LSP: declaration";
        }
        {
          mode = "n";
          key = "gi";
          lspBufAction = "implementation";
          options.desc = "LSP: implementation";
        }
        {
          mode = "n";
          key = "gr";
          lspBufAction = "references";
          options.desc = "LSP: references";
        }
        {
          mode = "n";
          key = "K";
          lspBufAction = "hover";
          options.desc = "LSP: hover";
        }
        {
          mode = "n";
          key = "[d";
          action = mkRaw "function() vim.diagnostic.jump({ count = -1, float = true }) end";
          options.desc = "Previous diagnostic";
        }
        {
          mode = "n";
          key = "]d";
          action = mkRaw "function() vim.diagnostic.jump({ count = 1, float = true }) end";
          options.desc = "Next diagnostic";
        }
        {
          mode = "n";
          key = "<leader>cd";
          action = mkRaw "vim.diagnostic.open_float";
          options.desc = "Line diagnostics";
        }
        {
          mode = "n";
          key = "<leader>cr";
          lspBufAction = "rename";
          options.desc = "LSP: rename";
        }
        {
          mode = [
            "n"
            "x"
          ];
          key = "<leader>ca";
          lspBufAction = "code_action";
          options.desc = "LSP: code action";
        }
      ];

      # Keys are the nvim-lspconfig config names; lookups (filetypes, root
      # markers) still use the Helix server names from the shared data.
      servers =
        lib.mapAttrs' (
          name: server:
            lib.nameValuePair (lspconfigNames.${name} or name) (mkServer name server)
        )
        languageServers;
    };
  };
}
