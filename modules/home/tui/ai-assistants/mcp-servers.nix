{
  pkgs,
  lib,
  config,
  ...
}: let
  # github-mcp-server reads the token at runtime from the sops-rendered
  # file. Passing it through MCP config env is not portable: opencode V1's
  # variable resolver throws on the {file:...} reference while building the
  # system prompt (killing every CLI run), and a plain env var ties the
  # server to the spawning shell. The wrapper serves every harness
  # (opencode V1/V2, Claude Code, the systemd web service) identically.
  github-mcp-server-wrapped = pkgs.writeShellApplication {
    name = "github-mcp-server";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.sops.secrets."github/token".path})"
      export GITHUB_PERSONAL_ACCESS_TOKEN
      exec ${pkgs.github-mcp-server}/bin/github-mcp-server "$@"
    '';
  };
in {
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
          command = "${github-mcp-server-wrapped}/bin/github-mcp-server";
          # stdio is mandatory from v0.22 on: a bare invocation prints the
          # usage text and exits, which opencode reports as "Connection
          # closed" for the whole server.
          args = ["stdio"];
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
      github-mcp-server-wrapped
      pkgs.mcp-nixos
      pkgs.mcp-language-server
    ];

    # Legacy definitions for Claude Code (which doesn't use programs.mcp)
    ai-assistants.mcpServers.definitions = {
      github = {
        package = github-mcp-server-wrapped;
        command = "github-mcp-server";
        # stdio is mandatory from v0.22 on; see programs.mcp.servers.github.
        args = ["stdio"];
        enabled = true;
        description = "GitHub repository operations and API access";
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
