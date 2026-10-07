{config, ...}: {
  programs.nixvim = {
    # rustaceanvim registers debug configurations through nvim-dap; its
    # default adapter autodetects the lldb-dap binary from the shared lldb
    # package, the same debugger Helix uses.
    plugins.dap.enable = true;

    # nvim-dap-ui renders scopes/stacks/repl during a session. rustaceanvim
    # starts sessions but never opens the UI, so dap's listeners below do.
    plugins.dap-ui.enable = true;
    extraConfigLua = ''
      local dap = require("dap")
      local dapui = require("dapui")
      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end
    '';

    plugins.rustaceanvim = {
      enable = true;
      # Single-sourced from the shared editor data: the absolute store-path
      # cmd so auto-attach and :checkhealth never depend on a bare
      # rust-analyzer in PATH, plus the same rust-analyzer configuration
      # (clippy on save) that Helix sends, here as default workspace settings.
      settings.server = {
        cmd = config.editors.languageServers."rust-analyzer".cmd;
        default_settings."rust-analyzer" = config.editors.languageServers."rust-analyzer".config;
      };
    };
  };
}
