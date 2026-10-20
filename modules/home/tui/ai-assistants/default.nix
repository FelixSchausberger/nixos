{...}: {
  imports = [
    ./mcp-servers.nix
    ./lsp-config.nix
    ./behaviors.nix
    ./safe-rm.nix
    ./herdr
    ./obsidian-skills.nix
    ./opencode
    ./opencode/v2.nix
    ./opencode/store-maintenance.nix
  ];
}
