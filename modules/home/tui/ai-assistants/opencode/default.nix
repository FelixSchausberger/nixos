{
  pkgs,
  config,
  lib,
  ...
}: let
  sharedBehaviors = config.ai-assistants.behaviors.definitions;
  sharedMcp = config.ai-assistants.mcpServers.definitions;

  # Combine all enabled behaviors into rules (global instructions)
  combinedRules = lib.concatStringsSep "\n\n---\n\n" (
    lib.mapAttrsToList (_name: behavior: "# ${behavior.description}\n\n${behavior.content}")
    (lib.filterAttrs (_n: v: v.enabled) sharedBehaviors)
  );

  # Generate opencode.json with MCP servers from shared definitions
  opencodeJsonContent = let
    mcpServers = lib.mapAttrs (_name: server: {
      type = "local";
      command = ["${server.package}/bin/${server.command}"];
    }) (lib.filterAttrs (_n: v: v.enabled) sharedMcp);
  in
    builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      mcp = mcpServers;
    };
in {
  imports = [
    ./openchamber-service.nix
    ./notifier.nix
  ];

  programs.opencode = {
    enable = true;

    # Wrap opencode with SSL certificate environment variables for Bun
    package = pkgs.symlinkJoin {
      name = "opencode-wrapped";
      paths = [pkgs.opencode];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/opencode \
          --set NODE_EXTRA_CA_CERTS "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
          --set NODE_TLS_REJECT_UNAUTHORIZED "0"
      '';
      meta.mainProgram = "opencode";
    };

    # Disable programs.mcp integration - we use project-level opencode.json instead
    # This gives us more control over environment variables
    enableMcpIntegration = false;

    # Use shared behaviors as global rules/instructions
    context = combinedRules;

    # Block raw git operations that bypass jj's commit graph.
    # Mirrors the patterns in claude-code/hooks/block-raw-git.sh.
    # Applied globally (all projects) since jj is used across all repos.
    settings = {
      model = "ollama-cloud/minimax-m2.7";
      small_model = "ollama-cloud/minimax-m2.7";
      agent = {
        plan.model = "ollama-cloud/glm-5.1";
        build.model = "ollama-cloud/minimax-m2.7";
      };
      plugin = ["opencode-code-simplifier"];
      permission = {
        bash = {
          "git reset*" = "deny";
          "git push --force*" = "deny";
          "git push -f *" = "deny";
          "git rebase*" = "deny";
          "git commit*" = "deny";
          "git stash*" = "deny";
          "git checkout * -- *" = "deny";
        };
      };
    };

    # Use built-in web service
    web = {
      enable = true;
      extraArgs = ["--port" "4096" "--hostname" "0.0.0.0" "--mdns"];
    };
  };

  # Generate opencode.json at project root with MCP servers and GitHub token
  # Uses activation script because home.file only works within $HOME
  home.activation.createOpenCodeMcpConfig = let
    tokenPath = config.sops.secrets."github/token".path;
  in
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -w /per/etc/nixos ]; then
        BASE_JSON='${opencodeJsonContent}'

        # Add GitHub token to MCP server environment if secret exists
        if [[ -f "${tokenPath}" ]]; then
          GITHUB_TOKEN=$(cat "${tokenPath}")
          $DRY_RUN_CMD printf '%s' "$BASE_JSON" | \
            ${pkgs.jq}/bin/jq --arg token "$GITHUB_TOKEN" \
              '.mcp.github.environment.GITHUB_TOKEN = $token' \
              > /per/etc/nixos/opencode.json
          echo "Created /per/etc/nixos/opencode.json with MCP servers and GitHub token"
        else
          echo "Warning: GitHub token not found, using opencode.json without GitHub MCP"
          $DRY_RUN_CMD printf '%s' "$BASE_JSON" > /per/etc/nixos/opencode.json
        fi

        $DRY_RUN_CMD chmod 644 /per/etc/nixos/opencode.json
      else
        echo "Warning: /per/etc/nixos/ is not writable, cannot create opencode.json" >&2
      fi
    '';

  # Set Ollama API key for Cloud models
  home.sessionVariables = {
    OLLAMA_API_KEY = config.sops.secrets."ollama/api-key".path;
  };

  sops.secrets = {
    "ollama/api-key" = {};
    "github/token" = {};
  };
}
