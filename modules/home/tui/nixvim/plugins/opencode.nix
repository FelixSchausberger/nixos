{config, ...}: let
  # HM host modules get nixvim's helpers from config.lib; the lib module arg
  # is plain Nixpkgs lib without the nixvim extension.
  inherit (config.lib.nixvim) mkRaw;
in {
  programs.nixvim = {
    plugins.opencode = {
      enable = true;
      # Connect to the same long-lived server as the oc function and the web
      # UI instead of spawning an instance from inside Neovim.
      settings.server.url = "http://127.0.0.1:4096";
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
