{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: let
  # Reference the custom packages from the flake
  inherit (inputs.self.packages.${pkgs.system}) mcp-language-server;
in {
  home = {
    packages =
      (with pkgs; [
        jq # For parsing JSON output in hooks
        # Development tools for hooks
        alejandra # Nix formatter
        deadnix # Dead code detection
        nixd # Nix LSP
        shellcheck # Shell script linter
        # MCP servers
        github-mcp-server
        mcp-nixos # NixOS MCP server (from nixpkgs)
        # Custom packages
        mcp-language-server
        # Claude Code itself
        claude-code
      ])
      ++ [
        # Usage tracking for statusline (from ccusage-flake)
        inputs.ccusage.packages.${pkgs.system}.default
      ];

    # Create project-level .mcp.json for MCP servers at actual project root
    # Using activation script because home.file only works within $HOME
    activation.createMcpJson = let
      mcpJsonContent = builtins.toJSON {
        mcpServers = {
          github = {
            type = "stdio";
            command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
            args = [];
          };
          nix-language-server = {
            type = "stdio";
            command = "${mcp-language-server}/bin/mcp-language-server";
            args = ["--workspace" "/per/etc/nixos" "--lsp" "nixd"];
          };
          nixos = {
            type = "stdio";
            command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
            args = [];
          };
        };
      };
    in
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        # Create .mcp.json at /per/etc/nixos/ (project root) for Claude Code MCP servers
        if [ -w /per/etc/nixos ]; then
          $DRY_RUN_CMD echo '${mcpJsonContent}' > /per/etc/nixos/.mcp.json
          $DRY_RUN_CMD chmod 644 /per/etc/nixos/.mcp.json
          echo "Created /per/etc/nixos/.mcp.json for Claude Code MCP servers"
        else
          echo "Warning: /per/etc/nixos/ is not writable, cannot create .mcp.json" >&2
        fi
      '';
  };

  programs.gh.enable = true; # GitHub CLI tool.

  # Write Claude Code configuration directly to file since Home Manager module doesn't support MCP servers
  xdg.configFile."claude-code/settings.json".text = let
    claudeStatusline = pkgs.writeShellScript "claude-statusline" (builtins.readFile ./statusline.sh);
    avoidAgreementHook = pkgs.writeShellScript "avoid-agreement-hook" (builtins.readFile ./hooks/avoid-agreement.sh);
    preventRebuildHook = pkgs.writeShellScript "prevent-rebuild-hook" (builtins.readFile ./hooks/prevent-rebuild.sh);
  in
    builtins.toJSON {
      hasCompletedOnboarding = true;
      includeCoAuthoredBy = false;
      shiftEnterKeyBindingInstalled = true;
      theme = "dark";

      # MCP server configuration - automatically approve all project MCP servers
      enableAllProjectMcpServers = true;

      permissions = {
        additionalDirectories = [
          "/per/etc/nixos"
        ];
        deny = [
          "Read(./.env)"
          "Read(./.env.*)"
          "Read(./secrets/**)"
          "Read(./config/credentials.json)"
          "Read(./build)"
        ];
      };

      environment.DISABLE_TELEMETRY = "1";

      hooks = {
        UserPromptSubmit = [
          {
            matcher = "*";
            hooks = [
              {
                type = "command";
                command = toString avoidAgreementHook;
              }
              {
                type = "command";
                command = toString preventRebuildHook;
              }
            ];
          }
        ];
      };

      statusLine = {
        type = "command";
        command = toString claudeStatusline;
      };
    };
}
