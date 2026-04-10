{
  pkgs,
  lib,
  ...
}: {
  # Create project-level .lsp.json for LSP servers at actual project root
  # Using activation script because home.file only works within $HOME
  home.activation.createLspJson = let
    lspJsonContent = builtins.toJSON {
      nix = {
        command = "${pkgs.nixd}/bin/nixd";
        extensionToLanguage = {
          ".nix" = "nix";
        };
      };
    };
  in
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Create .lsp.json at /per/etc/nixos/ (project root) for Claude Code/OpenCode LSP servers
      if [ -w /per/etc/nixos ]; then
        $DRY_RUN_CMD echo '${lspJsonContent}' > /per/etc/nixos/.lsp.json
        $DRY_RUN_CMD chmod 644 /per/etc/nixos/.lsp.json
        echo "Created /per/etc/nixos/.lsp.json for Claude Code/OpenCode LSP servers"
      else
        echo "Warning: /per/etc/nixos/ is not writable, cannot create .lsp.json" >&2
      fi
    '';
}
