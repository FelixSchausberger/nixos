# Shared nixpkgs overlays for package build fixes
# Used by hosts that need nixos-wizard or other packages with dependency issues
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # python-lsp-server has flaky tests that fail in CI, disable them
      python312Packages = prev.python312Packages.overrideScope (
        _: pyprev: {
          python-lsp-server = pyprev.python-lsp-server.overridePythonAttrs (_: {
            doCheck = false;
          });
        }
      );

      # aioboto3/aiobotocore tests fail with aiohttp 3.13+ due to "Duplicate 'Server' header"
      # in moto's mock server. Disable checks until upstream fixes the compatibility.
      python313Packages = prev.python313Packages.overrideScope (
        _: pyprev: {
          aioboto3 = pyprev.aioboto3.overridePythonAttrs (_: {
            doCheck = false;
          });
          aiobotocore = pyprev.aiobotocore.overridePythonAttrs (_: {
            doCheck = false;
          });
          # pytest-timeout is missing from nativeCheckInputs, so pyproject.toml's
          # timeout = 5 is silently ignored. Many tests use Docket/Worker which
          # hangs in the Nix sandbox asyncio environment with no safety net.
          # Task tests in tests/server/tasks/ (all 16 files) are particularly affected.
          fastmcp = pyprev.fastmcp.overridePythonAttrs (_: {
            doCheck = false;
          });
        }
      );
    })
  ];
}
