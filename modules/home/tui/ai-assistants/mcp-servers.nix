{
  pkgs,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.self.packages.${pkgs.hostPlatform.system}) mcp-language-server;
in {
  # Legacy: Keep ai-assistants.mcpServers.definitions for Claude Code compatibility
  # Claude Code doesn't integrate with programs.mcp, so it needs its own format
  options.ai-assistants.mcpServers = {
    definitions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
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
        };
      });
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
          args = [];
        };

        nix-language-server = {
          command = "${mcp-language-server}/bin/mcp-language-server";
          args = ["--workspace" "/per/etc/nixos" "--lsp" "nixd"];
        };

        nixos = {
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          args = [];
        };

        garnix-insights = {
          command = "${pkgs.garnix-insights}/bin/garnix-insights";
          args = ["mcp"];
        };
      };
    };

    # Provide MCP packages globally for all AI assistants
    home.packages = [
      pkgs.github-mcp-server
      pkgs.mcp-nixos
      mcp-language-server
      pkgs.garnix-insights
    ];

    # Legacy definitions for Claude Code (which doesn't use programs.mcp)
    ai-assistants.mcpServers.definitions = {
      github = {
        package = pkgs.github-mcp-server;
        command = "github-mcp-server";
        args = [];
        enabled = true;
        description = "GitHub repository operations and API access";
      };

      nix-language-server = {
        package = mcp-language-server;
        command = "mcp-language-server";
        args = ["--workspace" "/per/etc/nixos" "--lsp" "nixd"];
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

      garnix-insights = {
        package = pkgs.garnix-insights;
        command = "garnix-insights";
        args = ["mcp"];
        enabled = true;
        description = "Garnix CI/CD insights and build logs (requires GARNIX_JWT_TOKEN environment variable)";
      };
    };
  };
}
