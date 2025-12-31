{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.ai-assistants.vibe-kanban;
  sharedMcp = config.ai-assistants.mcpServers.definitions;
in {
  options.ai-assistants.vibe-kanban = {
    enable = lib.mkEnableOption "vibe-kanban task orchestration for AI coding agents";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for vibe-kanban web interface";
    };

    enableMcpIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Share MCP servers with vibe-kanban";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.vibe-kanban];

    systemd.user.services.vibe-kanban = {
      Unit = {
        Description = "Vibe Kanban task orchestration for AI agents";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.vibe-kanban}/bin/vibe-server";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "PORT=${toString cfg.port}"
          "FRONTEND_PORT=${toString cfg.port}"
          "HOST=127.0.0.1"
        ];
      };
      Install.WantedBy = ["default.target"];
    };

    # MCP integration - share existing MCP server definitions
    home.activation.vibeKanbanMcpConfig = lib.mkIf cfg.enableMcpIntegration (
      let
        mcpConfig = builtins.toJSON {
          mcpServers = lib.mapAttrs (_name: server: {
            command = "${server.package}/bin/${server.command}";
            inherit (server) args;
            env = {};
          }) (lib.filterAttrs (_n: v: v.enabled) sharedMcp);
        };
      in
        lib.hm.dag.entryAfter ["writeBoundary"] ''
          # Create MCP config directory for vibe-kanban
          $DRY_RUN_CMD mkdir -p $HOME/.config/vibe-kanban

          # Write MCP configuration in vibe-kanban's expected format
          $DRY_RUN_CMD echo '${mcpConfig}' > $HOME/.config/vibe-kanban/mcp-config.json
          $DRY_RUN_CMD chmod 644 $HOME/.config/vibe-kanban/mcp-config.json
          echo "Created MCP configuration for vibe-kanban with ${toString (builtins.length (builtins.attrNames sharedMcp))} servers"
        ''
    );

    # Shell aliases for convenience
    programs.fish.shellAliases = {
      vk = "systemctl --user status vibe-kanban";
      vk-logs = "journalctl --user -u vibe-kanban -f";
      vk-restart = "systemctl --user restart vibe-kanban";
    };
  };
}
