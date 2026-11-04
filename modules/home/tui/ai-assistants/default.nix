{...}: {
  imports = [
    ./mcp-servers.nix
    ./lsp-config.nix
    ./behaviors.nix
    ./safe-rm.nix
    ./herdr
    ./obsidian-skills.nix
    ./opencode
    ./opencode/opencode.nix
    ./opencode/store-maintenance.nix
  ];
}
