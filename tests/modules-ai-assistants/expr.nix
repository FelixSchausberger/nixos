# Test: ai-assistants module shared definitions
{flake, ...}: let
  # Get the hp-probook-wsl home config (which has ai-assistants enabled) from the flake
  homeConfig = flake.nixosConfigurations.hp-probook-wsl.config.home-manager.users.schausberger;

  # Get shared definitions
  mcpServers = homeConfig.ai-assistants.mcpServers.definitions;
  behaviors = homeConfig.ai-assistants.behaviors.definitions;
  store = homeConfig.ai-assistants.opencode.store;
in {
  # Test: MCP server definitions exist
  has_mcp_servers = builtins.length (builtins.attrNames mcpServers) > 0;
  mcp_server_count = builtins.length (builtins.attrNames mcpServers);
  mcp_server_names = builtins.attrNames mcpServers;

  # Test: nix-language-server MCP is configured correctly
  nix_lang_mcp_exists = builtins.hasAttr "nix-language-server" mcpServers;
  nix_lang_mcp_enabled = mcpServers.nix-language-server.enabled or false;
  nix_lang_mcp_has_args = builtins.length (mcpServers.nix-language-server.args or []) > 0;

  # Test: NixOS MCP server is configured correctly
  nixos_mcp_exists = builtins.hasAttr "nixos" mcpServers;
  nixos_mcp_enabled = mcpServers.nixos.enabled or false;

  # Test: Behavior definitions exist
  has_behaviors = builtins.length (builtins.attrNames behaviors) > 0;
  behavior_count = builtins.length (builtins.attrNames behaviors);
  behavior_names = builtins.attrNames behaviors;

  # Test: avoid-agreement behavior
  avoid_agreement_exists = builtins.hasAttr "avoid-agreement" behaviors;
  avoid_agreement_enabled = behaviors.avoid-agreement.enabled or false;
  avoid_agreement_has_content = builtins.stringLength (behaviors.avoid-agreement.content or "") > 0;

  # Test: prevent-rebuild behavior
  prevent_rebuild_exists = builtins.hasAttr "prevent-rebuild" behaviors;
  prevent_rebuild_enabled = behaviors.prevent-rebuild.enabled or false;
  prevent_rebuild_priority = behaviors.prevent-rebuild.priority or null;

  # Test: additional-context behavior
  additional_context_exists = builtins.hasAttr "additional-context" behaviors;
  additional_context_enabled = behaviors.additional-context.enabled or false;

  # Test: session store maintenance defaults. The size budget is the only
  # trigger and the destructive path ships disabled, so both are pinned here.
  store_enabled = store.enable;
  store_max_gib = store.maxStoreGib;
  store_keep_days = store.keepDays;
  store_cache_max_age_days = store.cacheMaxAgeDays;
  store_dry_run = store.dryRun;
  store_archive_dir_is_default =
    builtins.match ".*/opencode/archive/pruned" store.archiveDir != null;
}
