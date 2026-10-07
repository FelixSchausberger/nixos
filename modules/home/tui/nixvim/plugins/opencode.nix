{
  config,
  pkgs,
  ...
}: let
  # HM host modules get nixvim's helpers from config.lib; the lib module arg
  # is plain Nixpkgs lib without the nixvim extension.
  inherit (config.lib.nixvim) mkRaw;
  v2 = config.ai-assistants.opencodeV2.enable;
in {
  programs.nixvim = {
    plugins.opencode = {
      enable = true;

      # nixpkgs ships opencode.nvim 1.0.2, which speaks the V1 protocol
      # (`{type, properties}` events, `/tui/*` endpoints). The shared server
      # this fleet runs is OpenCode 2, so pin the upstream branch that moved to
      # the V2 API. Drop the override once a release with the `{id, type, data}`
      # event shape ships. Rev 06770e2e3618 (2026-09-24).
      package = pkgs.vimUtils.buildVimPlugin {
        pname = "opencode.nvim";
        version = "unstable-2026-09-24";
        src = pkgs.fetchFromGitHub {
          owner = "NickvanDyke";
          repo = "opencode.nvim";
          rev = "06770e2e3618b82703e3e7af1f2d5dc67bde0002";
          hash = "sha256-cY56YBPNQsutfTBtOsMkJaLRvxjQM4mO61A5w9Q8HWs=";
        };
      };

      # Connect to the same shared server as the oc function and the web UI
      # instead of spawning an instance from inside Neovim. On V2 the URL and
      # the basic-auth password come from the running service registration
      # (lua/config/opencode_server.lua); V1 has no authentication, so the
      # fixed URL is all it needs.
      settings.server =
        if v2
        then {
          url = mkRaw ''require("config.opencode_server").url()'';
          password = mkRaw ''require("config.opencode_server").password()'';
        }
        else {
          url = "http://127.0.0.1:4096";
        };
    };

    # The unwrapped nixpkgs opencode would shadow the wrapped package
    # (OPENCODE_DB pin and wrapper environment) on nvim's PATH prefix.
    dependencies.opencode.package = config.programs.opencode.package;

    # Editor integration: ask with context, pick sessions/prompts, and send
    # ranges or lines from the buffer.
    keymaps = [
      {
        mode = [
          "n"
          "x"
        ];
        key = "<C-a>";
        action = mkRaw ''function() require("opencode").ask("@this: ") end'';
        options.desc = "Ask OpenCode";
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "<C-x>";
        action = mkRaw ''function() require("opencode").select() end'';
        options.desc = "Select OpenCode";
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "go";
        action = mkRaw ''function() return require("opencode").operator("@this ") end'';
        options = {
          expr = true;
          desc = "Send range to OpenCode";
        };
      }
      {
        mode = "n";
        key = "goo";
        action = mkRaw ''function() return require("opencode").operator("@this ") .. "_" end'';
        options = {
          expr = true;
          desc = "Send line to OpenCode";
        };
      }
    ];
  };
}
