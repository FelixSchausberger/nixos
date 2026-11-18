---
name: nix-testing
description: Use when writing or running tests for this NixOS flake: namaka snapshots, tests-vm integration tests, or package checks. Covers the three test layers and their commands.
license: MIT
compatibility: opencode
---

## Role

Testing guide for this flake. There are three layers; use the lowest one that
covers the change.

## Layers

| Layer | Location | Run |
| --- | --- | --- |
| Namaka snapshots | `tests/` | `namaka check` (update with `namaka review`) |
| VM integration | `tests-vm/default.nix` | `just test-vm <name>` or `nix build .#packages.x86_64-linux.test-<name>` |
| Package checks | derivation `passthru.tests` / `doCheck` | `nix build .#<pkg>.passthru.tests`, `nix flake check` |

## Workflow

1. Read the existing test nearest the change before writing a new one.
2. Namaka: add or update the case in `tests/`; snapshots are committed, so an
   intentional change needs `namaka review` and the snapshot update in the
   same change.
3. VM tests: every attribute in `tests-vm/default.nix` becomes
   `packages.test-<name>` and is built by `just test-vm-all`; there is no
   separate registry.
4. Validate with `nix fmt`, `prek run --all-files`, `namaka check`,
   `nix flake check`, and the package instantiation eval from `AGENTS.md`
   (flake check is WHNF-only).
5. Report which layer ran and what was skipped.

## Conventions

- `passthru.tests` is the nixpkgs convention; there is no `meta.tests`.
- `doCheck` defaults to false (`doCheckByDefault`); enable it only when the
  upstream suite is hermetic in the sandbox.
- VM tests must assert the layer production uses; do not enable a mode the
  host disables just to make the test pass.
- Prefer a CLI diagnostic (`nix flake check`, `statix`, `deadnix`) over a new
  test when it already catches the failure.
