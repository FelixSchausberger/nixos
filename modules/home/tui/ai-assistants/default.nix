{...}: {
  imports = [
    ./mcp-servers.nix
    ./lsp-config.nix
    ./behaviors.nix
    ./herdr
    ./obsidian-skills.nix
    # ./claude-code
    ./opencode
  ];
}
