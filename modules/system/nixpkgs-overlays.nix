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

      # system-level python3Packages resolves to python314 on this nixpkgs
      python314Packages = prev.python314Packages.overrideScope (
        _: pyprev: {
          python-lsp-server = pyprev.python-lsp-server.overridePythonAttrs (_: {
            doCheck = false;
          });

          # AI/MCP servers pull a check-dependency cascade
          # fastmcp→py-key-value-aio→py-key-value-shared→inline-snapshot→isort→
          # pylama→vulture→pint→uncertainties→scipy. scipy's hypothesis-based
          # tests are flaky against numpy 2.5 array_api and fail in the sandbox.
          # Disable checks along the whole chain so scipy is never even built.
          fastmcp = pyprev.fastmcp.overridePythonAttrs (_: {
            doCheck = false;
          });
          py-key-value-aio = pyprev.py-key-value-aio.overridePythonAttrs (_: {
            doCheck = false;
          });
          py-key-value-shared = pyprev.py-key-value-shared.overridePythonAttrs (_: {
            doCheck = false;
          });
          inline-snapshot = pyprev.inline-snapshot.overridePythonAttrs (_: {
            doCheck = false;
          });
          isort = pyprev.isort.overridePythonAttrs (_: {
            doCheck = false;
          });
          pylama = pyprev.pylama.overridePythonAttrs (_: {
            doCheck = false;
          });
          vulture = pyprev.vulture.overridePythonAttrs (_: {
            doCheck = false;
          });
          pint = pyprev.pint.overridePythonAttrs (_: {
            doCheck = false;
          });
          uncertainties = pyprev.uncertainties.overridePythonAttrs (_: {
            doCheck = false;
          });
          scipy = pyprev.scipy.overridePythonAttrs (_: {
            doCheck = false;
          });
        }
      );

      # poetry 2.4.1 has flaky test_executor tests that fail in the nix sandbox
      poetry = prev.poetry.overridePythonAttrs (_: {
        doCheck = false;
      });

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

      # The nixos-unstable channel removed buildGo125Module when Go 1.25 hit
      # end-of-life (26.11pre1074753). sops-nix's module resolves its install
      # helper from the consuming host's package set
      # (config.sops.package default is (pkgs.callPackage ../.. {})
      # .sops-install-secrets with hardcoded buildGo125Module), so the alias
      # throw hits every deployment regardless of sops-nix input follows.
      # Map the removed alias onto the current buildGoModule; the Go 1.25
      # source code builds under the channel's newer Go. Walker dependency
      # elephant is fixed at flake-level via a nested input follow instead
      # (its package set bypasses this overlay entirely).
      buildGo125Module = prev.buildGoModule;
    })
  ];
}
