# Shared nixpkgs overlays for package build fixes
# Used by hosts that need nixos-wizard or other packages with dependency issues
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # python-lsp-server has flaky tests that fail in CI, disable them
      python312Packages = prev.python312Packages.overrideScope (_: pyprev: {
        python-lsp-server = pyprev.python-lsp-server.overridePythonAttrs (_: {
          doCheck = false;
        });
      });
    })
  ];
}
