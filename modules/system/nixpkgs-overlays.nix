# Shared nixpkgs overlays for package build fixes
# Used by hosts that need nixos-wizard or other packages with dependency issues
_: {
  nixpkgs.overlays = [
    (final: prev: {
      # python-lsp-server has flaky tests that fail in CI, disable them
      python312Packages = prev.python312Packages.overrideScope (_: pyprev: {
        python-lsp-server = pyprev.python-lsp-server.overridePythonAttrs (_: {
          doCheck = false;
        });
      });

      # fastmcp has mcp version conflict (requires <1.17.0, nixpkgs has 1.25.0)
      # Skip runtime dependency check and tests to allow mcp-nixos to build
      python313Packages = prev.python313Packages.overrideScope (_: pyprev: {
        fastmcp = pyprev.fastmcp.overridePythonAttrs (_: {
          doCheck = false;
          dontCheckRuntimeDeps = true;
        });
      });

      # mcp-nixos depends on fastmcp, rebuild with overridden python313Packages
      mcp-nixos = prev.mcp-nixos.override {
        python3Packages = final.python313Packages;
      };

      # oculante has CMake/nasm build issues, disable for now
      # Alternative: Use feh or imv as lightweight image viewers
      oculante = prev.runCommand "oculante-stub" {} ''
        mkdir -p $out/bin
        echo "#!/bin/sh" > $out/bin/oculante
        echo "echo 'oculante is disabled due to build issues'" >> $out/bin/oculante
        chmod +x $out/bin/oculante
      '';
    })
  ];
}
