{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  claudeCodePackage = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  sharedMcp = config.ai-assistants.mcpServers.definitions;
  sharedBehaviors = config.ai-assistants.behaviors.definitions;

  combinedContext = lib.concatStringsSep "\n\n---\n\n" (
    lib.mapAttrsToList (_name: behavior: "# ${behavior.description}\n\n${behavior.content}") (
      lib.filterAttrs (_n: v: v.enabled) sharedBehaviors
    )
  );

  sharedSkills = ../skills;

  avoidAgreementHook = pkgs.writeShellScript "avoid-agreement.sh" (
    builtins.readFile ./hooks/avoid-agreement.sh
  );
  preventRebuildHook = pkgs.writeShellScript "prevent-rebuild.sh" (
    builtins.readFile ./hooks/prevent-rebuild.sh
  );
  additionalContextHook = pkgs.writeShellScript "additional-context.sh" (
    builtins.readFile ./hooks/additional-context.sh
  );
  blockRawGitHook = pkgs.writeShellScript "block-raw-git.sh" (
    builtins.readFile ./hooks/block-raw-git.sh
  );
  documentationPolicyHook = pkgs.writeShellScript "documentation-policy.sh" (
    builtins.readFile ./hooks/documentation-policy.sh
  );

  hooksDir = pkgs.runCommand "claude-code-hooks" {} ''
    mkdir -p $out
    ln -s ${avoidAgreementHook} $out/avoid-agreement.sh
    ln -s ${preventRebuildHook} $out/prevent-rebuild.sh
    ln -s ${additionalContextHook} $out/additional-context.sh
    ln -s ${blockRawGitHook} $out/block-raw-git.sh
    ln -s ${documentationPolicyHook} $out/documentation-policy.sh
  '';

  orchestratorHook = pkgs.writeShellScript "orchestrator-hook" (
    builtins.replaceStrings ["@hooksDir@"] ["${hooksDir}"] (
      builtins.readFile ./hooks/orchestrator.sh
    )
  );

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
      {
        matcher = "Write|Edit";
        hooks = [
          {
            type = "command";
            command = toString documentationPolicyHook;
          }
        ];
      }
    ];
  };

  claudeStatusline = pkgs.writeShellScript "claude-statusline" (builtins.readFile ./statusline.sh);

  mcpJsonContent = builtins.toJSON {
    mcpServers = lib.mapAttrs (_name: server: {
      type = "stdio";
      command = "${server.package}/bin/${server.command}";
      inherit (server) args;
    }) (lib.filterAttrs (_n: v: v.enabled) sharedMcp);
  };
in {
  home = {
    packages =
      (with pkgs; [
        jq
        alejandra
        deadnix
        nixd
        shellcheck
      ])
      ++ (lib.attrValues (
        lib.mapAttrs (_n: v: v.package) (lib.filterAttrs (_n: v: v.enabled) sharedMcp)
      ));

    activation.createMcpJson = let
      tokenPath = config.sops.secrets."github/token".path;
    in
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        if [ -w /per/etc/nixos ]; then
          BASE_JSON='${mcpJsonContent}'
          if [[ -f "${tokenPath}" ]]; then
            GITHUB_TOKEN=$(cat "${tokenPath}")
            $DRY_RUN_CMD printf '%s' "$BASE_JSON" | \
              ${pkgs.jq}/bin/jq --arg token "$GITHUB_TOKEN" \
                '.mcpServers.github.env = {"GITHUB_TOKEN": $token}' \
              > /per/etc/nixos/.mcp.json
            echo "Created /per/etc/nixos/.mcp.json for Claude Code MCP servers"
          else
            echo "Warning: GitHub token not found, MCP github server will not authenticate" >&2
            $DRY_RUN_CMD printf '%s' "$BASE_JSON" > /per/etc/nixos/.mcp.json
          fi
          $DRY_RUN_CMD chmod 644 /per/etc/nixos/.mcp.json
        else
          echo "Warning: /per/etc/nixos/ is not writable, cannot create .mcp.json" >&2
        fi
      '';
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = false;
    settings = {
      git_protocol = "https";
    };
  };

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

  programs.claude-code = {
    enable = true;

    package = claudeCodePackage;

    context = combinedContext;

    skills = sharedSkills;

    agents = {
      nix-expert = ./agents/nix-expert.md;
      nix-testing = ./agents/nix-testing.md;
    };

    settings = {
      hasCompletedOnboarding = true;
      includeCoAuthoredBy = false;
      shiftEnterKeyBindingInstalled = true;
      theme = "dark";
      enableAllProjectMcpServers = true;
      permissions = {
        additionalDirectories = ["/per/etc/nixos"];
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
  };
}
