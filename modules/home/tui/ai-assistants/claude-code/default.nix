{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  # Use claude-code from sadjow/claude-code-nix for hourly updates
  claudeCodePackage = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Use shared MCP server definitions from ai-assistants module
  sharedMcp = config.ai-assistants.mcpServers.definitions;
in {
  imports = [
    ./good-morning.nix
  ];
  home = {
    packages =
      (with pkgs; [
        jq # For parsing JSON output in hooks
        # Development tools for hooks
        alejandra # Nix formatter
        deadnix # Dead code detection
        nixd # Nix LSP
        shellcheck # Shell script linter
        # Claude Code itself
        claudeCodePackage
      ])
      # MCP server packages from shared definitions
      ++ (lib.attrValues (lib.mapAttrs (_n: v: v.package) (lib.filterAttrs (_n: v: v.enabled) sharedMcp)));

    # Create project-level .mcp.json for MCP servers at actual project root
    # Using activation script because home.file only works within $HOME
    # Uses shared MCP server definitions from ai-assistants module
    activation.createMcpJson = let
      mcpJsonContent = builtins.toJSON {
        mcpServers = lib.mapAttrs (_name: server: {
          type = "stdio";
          command = "${server.package}/bin/${server.command}";
          inherit (server) args;
        }) (lib.filterAttrs (_n: v: v.enabled) sharedMcp);
      };
    in
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        # Create .mcp.json at /per/etc/nixos/ (project root) for Claude Code MCP servers
        if [ -w /per/etc/nixos ]; then
          BASE_JSON='${mcpJsonContent}'
          if [[ -f ${config.sops.secrets."github/token".path} ]]; then
            GITHUB_TOKEN=$(cat ${config.sops.secrets."github/token".path})
            $DRY_RUN_CMD printf '%s' "$BASE_JSON" | \
              ${pkgs.jq}/bin/jq --arg token "$GITHUB_TOKEN" \
                '.mcpServers.github.env = {"GITHUB_TOKEN": $token}' \
              > /per/etc/nixos/.mcp.json
          else
            echo "Warning: GitHub token not found, MCP github server will not authenticate" >&2
            $DRY_RUN_CMD printf '%s' "$BASE_JSON" > /per/etc/nixos/.mcp.json
          fi
          $DRY_RUN_CMD chmod 644 /per/etc/nixos/.mcp.json
          echo "Created /per/etc/nixos/.mcp.json for Claude Code MCP servers"
        else
          echo "Warning: /per/etc/nixos/ is not writable, cannot create .mcp.json" >&2
        fi
      '';
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = false; # Disable gh credential helper to avoid conflicts
    settings = {
      git_protocol = "https";
    };
  };

  # Configure GitHub authentication using sops-managed token
  # Note: Cannot use xdg.configFile with sops secrets as the file content is only available at activation time
  # Using home.activation to read the secret file at runtime
  home.activation.ghConfig = config.lib.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p $HOME/.config/gh
        if [[ -f ${config.sops.secrets."github/token".path} ]]; then
          token=$(cat ${config.sops.secrets."github/token".path})
          cat > $HOME/.config/gh/hosts.yml <<EOF
    github.com:
        user: FelixSchausberger
        oauth_token: $token
        git_protocol: https
    EOF
        else
          echo "Warning: GitHub token file not found at ${config.sops.secrets."github/token".path}" >&2
        fi
  '';

  sops.secrets = {
    "github/token" = {};
  };

  # Write Claude Code configuration directly to file since Home Manager module doesn't support MCP servers
  xdg.configFile."claude-code/settings.json".text = let
    claudeStatusline = pkgs.writeShellScript "claude-statusline" (builtins.readFile ./statusline.sh);

    # Create individual hook scripts
    avoidAgreementHook = pkgs.writeShellScript "avoid-agreement.sh" (builtins.readFile ./hooks/avoid-agreement.sh);
    preventRebuildHook = pkgs.writeShellScript "prevent-rebuild.sh" (builtins.readFile ./hooks/prevent-rebuild.sh);
    additionalContextHook = pkgs.writeShellScript "additional-context.sh" (builtins.readFile ./hooks/additional-context.sh);
    blockRawGitHook = pkgs.writeShellScript "block-raw-git.sh" (builtins.readFile ./hooks/block-raw-git.sh);

    # Create hooks directory with all individual hooks
    hooksDir = pkgs.runCommand "claude-code-hooks" {} ''
      mkdir -p $out
      ln -s ${avoidAgreementHook} $out/avoid-agreement.sh
      ln -s ${preventRebuildHook} $out/prevent-rebuild.sh
      ln -s ${additionalContextHook} $out/additional-context.sh
      ln -s ${blockRawGitHook} $out/block-raw-git.sh
    '';

    # Create orchestrator with hooks directory path substituted
    orchestratorHook = pkgs.writeShellScript "orchestrator-hook" (
      builtins.replaceStrings ["@hooksDir@"] ["${hooksDir}"] (builtins.readFile ./hooks/orchestrator.sh)
    );

    # Build hooks configuration
    hooksConfig = {
      UserPromptSubmit = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = toString orchestratorHook;
            }
          ];
        }
      ];
      # Block raw git operations that bypass jj's commit graph.
      # Prevents the regression where git-level squash drops jj-only commits.
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = toString blockRawGitHook;
            }
          ];
        }
      ];
    };
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

      hooks = hooksConfig;

      statusLine = {
        type = "command";
        command = toString claudeStatusline;
      };
    };
}
