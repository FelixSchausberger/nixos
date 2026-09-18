{
  pkgs,
  lib,
  config,
  ...
}: {
  # Legacy: Keep ai-assistants.mcpServers.definitions for Claude Code compatibility
  # Claude Code doesn't integrate with programs.mcp, so it needs its own format
  options.ai-assistants.mcpServers = {
    definitions = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            package = lib.mkOption {
              type = lib.types.package;
              description = "Package containing the MCP server binary";
            };
            command = lib.mkOption {
              type = lib.types.str;
              description = "Command name to execute (binary name)";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Arguments to pass to the MCP server";
            };
            enabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether this MCP server is enabled";
            };
            description = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable description of the MCP server";
            };
            env = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = {};
              description = "Environment variables to pass to the MCP server";
            };
          };
        }
      );
      default = {};
      description = "MCP server definitions for Claude Code (which doesn't use programs.mcp)";
    };
  };

  config = {
    # Enable global MCP server configuration via programs.mcp
    # OpenCode will use this via enableMcpIntegration
    programs.mcp = {
      enable = true;

      # Define MCP servers globally
      servers = {
        github = {
          command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
          # stdio is mandatory from v0.22 on: a bare invocation prints the
          # usage text and exits, which opencode reports as "Connection
          # closed" for the whole server.
          args = ["stdio"];
          # File reference: opencode substitutes {file:...} at config load
          # (variable substitution in packages/core/src/config/variable.ts), so
          # the token reaches the server regardless of the spawning shell's
          # environment - the systemd web service and SSH-spawned opencode2
          # included, which never inherit the fish login-shell export.
          # GITHUB_PERSONAL_ACCESS_TOKEN: upstream renamed GITHUB_TOKEN away
          # in v1.x and only reads the new name for stdio auth.
          env.GITHUB_PERSONAL_ACCESS_TOKEN.file = config.sops.secrets."github/token".path;
        };

        nix-language-server = {
          command = "${pkgs.mcp-language-server}/bin/mcp-language-server";
          args = [
            "--workspace"
            "/per/etc/nixos"
            "--lsp"
            "nixd"
          ];
        };

        nixos = {
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          args = [];
        };
      };
    };

    # Provide MCP packages globally for all AI assistants
    home.packages = [
      pkgs.github-mcp-server
      pkgs.mcp-nixos
      pkgs.mcp-language-server
    ];

    # Legacy definitions for Claude Code (which doesn't use programs.mcp)
    ai-assistants.mcpServers.definitions = {
      github = {
        package = pkgs.github-mcp-server;
        command = "github-mcp-server";
        # stdio is mandatory from v0.22 on; see programs.mcp.servers.github.
        args = ["stdio"];
        enabled = true;
        description = "GitHub repository operations and API access";
        # Upstream renamed GITHUB_TOKEN away in v1.x; stdio only reads the
        # new name. Claude Code expands ${VAR} in mcp.json env values and
        # always runs from a fish login shell, where GITHUB_TOKEN is set.
        env.GITHUB_PERSONAL_ACCESS_TOKEN = "${"$"}{GITHUB_TOKEN}";
      };

      nix-language-server = {
        package = pkgs.mcp-language-server;
        command = "mcp-language-server";
        args = [
          "--workspace"
          "/per/etc/nixos"
          "--lsp"
          "nixd"
        ];
        enabled = true;
        description = "Semantic Nix code navigation (go to definition, find references, rename, diagnostics, hover)";
      };

      nixos = {
        package = pkgs.mcp-nixos;
        command = "mcp-nixos";
        args = [];
        enabled = true;
        description = "NixOS package/option lookup (130K+ packages, 22K+ options, Home Manager, nix-darwin)";
      };
    };
  };
}
