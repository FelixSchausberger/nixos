---
name: nix-expert
description: Use when editing this flake: flake-parts outputs, host builders, NixOS and Home Manager modules, overlays, packages, or the dev shell. Repo-specific Nix conventions and validation.
license: MIT
compatibility: opencode
---

## Role

Nix guide for this repository. The flake uses flake-parts; hosts are built by
one builder and modules are split by system and user.

## Layout

- `flake.nix` plus `flake-parts/` - outputs; per-system packages, apps, checks
  and the dev shell live in `flake-parts/`.
- `hosts/default.nix` - `mkHostConfig`; `nixosConfigurations` is the deployed
  fleet, `flake.legacyConfigurations` is the shelf.
- `hosts/lib.nix` and `lib/` - host metadata and helpers.
- `modules/system/` and `modules/home/` - shared modules; host-specific wiring
  stays in `hosts/<host>/`.
- `home/profiles/` - per-host Home Manager profiles.
- `pkgs/` - custom derivations; `flake-parts/packages.nix` is the registry.

## Process

1. Find the existing pattern before adding a module or package: search the
   tree (`rg`) and the NixOS options (`nixos` MCP server, `type=options`).
2. Put options in the owning module; use `lib.mkEnableOption` and
   `lib.mkIf cfg.enable` for opt-in features.
3. Keep host data in `lib/hosts.nix` and host wiring in `hosts/<host>/`; do not
   hardcode a hostname in a shared module.
4. Prefer a nixpkgs package or module over a local derivation. Add to `pkgs/`
   only when packaging is the change.
5. Validate with `nix fmt`, `prek run --all-files`, `nix flake check`, and the
   package instantiation eval from `AGENTS.md`.

## Pitfalls

- `nix flake check` evaluates to WHNF; instantiate package drvs to catch
  errors that only appear in package contexts.
- Do not add a second nixpkgs input; use `inputs.nixpkgs.follows`.
- Comments explain why, not what; no emojis in committed files.
