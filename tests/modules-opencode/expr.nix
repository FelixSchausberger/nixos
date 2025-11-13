# Test: opencode module configuration using Home Manager integration
{flake, ...}: let
  # Get the hp-probook-wsl home config (which has OpenCode enabled) from the flake
  homeConfig = flake.nixosConfigurations.hp-probook-wsl.config.home-manager.users.schausberger;
in {
  # Test: OpenCode is enabled via ai-assistants wrapper
  opencode_wrapper_enabled = homeConfig.ai-assistants.opencode.enable or false;

  # Test: Home Manager's opencode module is enabled
  opencode_hm_enabled = homeConfig.programs.opencode.enable or false;

  # Test: OpenCode package is in home.packages
  has_opencode_package = builtins.any (pkg: pkg.pname or "" == "opencode") homeConfig.home.packages;

  # Test: MCP integration is enabled (uses global programs.mcp)
  mcp_integration_enabled = homeConfig.programs.opencode.enableMcpIntegration or false;

  # Test: Global MCP module is enabled
  global_mcp_enabled = homeConfig.programs.mcp.enable or false;

  # Test: Global MCP servers are configured
  has_mcp_servers = builtins.hasAttr "servers" (homeConfig.programs.mcp or {});

  # Test: OpenCode rules (behaviors) are configured
  has_rules = (homeConfig.programs.opencode.rules or "") != "";

  # Test: Project-scoped config activation is set up
  has_project_config_activation = builtins.hasAttr "createOpenCodeProjectConfig" homeConfig.home.activation;
  project_config_enabled = homeConfig.ai-assistants.opencode.enableProjectConfig or false;
}
