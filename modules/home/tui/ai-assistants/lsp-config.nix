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
      # Use umask to create file with 0644 permissions directly (avoids chmod on restrictive filesystems)
      if [ -w /per/etc/nixos ] && { [ ! -e /per/etc/nixos/.lsp.json ] || [ -w /per/etc/nixos/.lsp.json ]; }; then
        (umask 022 && $DRY_RUN_CMD echo '${lspJsonContent}' > /per/etc/nixos/.lsp.json 2>/dev/null) || true
        echo "Created /per/etc/nixos/.lsp.json for Claude Code/OpenCode LSP servers"
      else
        echo "Warning: /per/etc/nixos/ is not writable, skipping .lsp.json creation" >&2
      fi
    '';
}
