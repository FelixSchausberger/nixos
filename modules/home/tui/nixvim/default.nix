{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./autocommands.nix
    ./keymaps.nix
    ./options.nix
    ./plugins
  ];

  # Live-config aliases (viAlias/vimAlias/vimdiffAlias below cover vim/vi).
  home.shellAliases.v = "nvim";

  # https://nix-community.github.io/nixvim/search/
  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    luaLoader.enable = true;

    # Reuse the host's nixpkgs evaluation: one import pass and one closure,
    # which is what the flake's nixvim follows declaration intends. Constructing
    # nixvim's own pkgs from its pinned input instead would warn about the
    # follows mismatch on every eval.
    nixpkgs.pkgs = pkgs;

    # Neovim 0.13 nightly instead of nixpkgs' 0.12.x: the conceal-aware
    # 'wrap' (render-markdown's treesitter conceal reflows correctly when
    # writing markdown notes) and the watcher-based 'autoread' (open
    # opencode plan files refresh while agents edit them). The overlay
    # pins its own nixpkgs and has no upstream builder, so the pinned rev
    # substitutes from the personal cache after a deliberate bump.
    package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # Bespoke logic stays in real Lua files under lua/, loaded here.
    extraFiles."lua/config/clipboard.lua".source = ./lua/config/clipboard.lua;
    extraFiles."lua/config/opencode_server.lua".source = ./lua/config/opencode_server.lua;
    extraFiles."lua/config/scooter.lua".source = ./lua/config/scooter.lua;
    extraFiles."lua/config/title.lua".source = ./lua/config/title.lua;

    extraConfigLua = ''
      require("config.clipboard")
      require("config.scooter")
      require("config.title")
    '';
  };
}
