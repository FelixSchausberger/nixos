{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.ai-assistants.opencode;
  sharedBehaviors = config.ai-assistants.behaviors.definitions;

  # Combine all enabled behaviors into rules (global instructions)
  combinedRules = lib.concatStringsSep "\n\n---\n\n" (
    lib.mapAttrsToList (_name: behavior: "# ${behavior.description}\n\n${behavior.content}")
    (lib.filterAttrs (_n: v: v.enabled) sharedBehaviors)
  );
in {
  options.ai-assistants.opencode = {
    enable = lib.mkEnableOption "OpenCode AI coding assistant with shared MCP servers and behaviors";

    enableProjectConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create project-scoped config.json at /per/etc/nixos/opencode.json";
    };
  };

  config = lib.mkIf cfg.enable {
    # Use Home Manager's built-in opencode module
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
      };

      # Use global MCP servers from programs.mcp via integration
      enableMcpIntegration = true;

      # Configure OpenCode settings
      # Note: OpenCode config.json doesn't support 'permissions.deny' or top-level 'environment'
      # Using only valid keys from https://opencode.ai/config.json schema
      settings = {};

      # Use shared behaviors as global rules/instructions
      rules = combinedRules;
    };

    # Generate project-scoped config.json via activation script
    # Home Manager generates ~/.config/opencode/config.json, we copy it to project root
    home.activation.createOpenCodeProjectConfig = lib.mkIf cfg.enableProjectConfig (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        # Create config.json at /per/etc/nixos/ (project root) for OpenCode
        if [ -w /per/etc/nixos ]; then
          # Copy the generated config from home directory to project root as opencode.json
          if [ -f ${config.home.homeDirectory}/.config/opencode/config.json ]; then
            $DRY_RUN_CMD cp ${config.home.homeDirectory}/.config/opencode/config.json /per/etc/nixos/opencode.json
            $DRY_RUN_CMD chmod 644 /per/etc/nixos/opencode.json
            echo "Created /per/etc/nixos/opencode.json for OpenCode (project-scoped config)"
          else
            echo "Warning: OpenCode config not found at ${config.home.homeDirectory}/.config/opencode/config.json" >&2
          fi
        else
          echo "Warning: /per/etc/nixos/ is not writable, cannot create opencode.json" >&2
        fi
      ''
    );
  };
}
