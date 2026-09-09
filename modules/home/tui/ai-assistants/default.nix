{...}: {
  imports = [
    ./mcp-servers.nix
    ./lsp-config.nix
    ./behaviors.nix
    ./safe-rm.nix
    ./herdr
    ./obsidian-skills.nix
    # ./claude-code
    ./opencode
  ];
}
