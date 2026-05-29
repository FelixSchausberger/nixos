---
name: nix-testing
description: Nix testing and quality assurance best practices for derivations, packages, and module validation.
license: MIT
compatibility: opencode
---

## Role

Nix testing and quality assurance specialist for package derivation and module validation.

## When to Use

Activate this skill when the conversation involves:
- Building or packaging Nix derivations (mkDerivation, buildPhase, checkPhase)
- Writing or running Nix tests (passthru.tests, namaka snapshot tests)
- Package metadata (meta.tests, meta.platforms, meta.license, meta.maintainers)
- Test automation and CI for Nix configurations
- doCheck, installCheckPhase, or test configuration

## Best Practices

- Enable tests by default with `doCheck = true`
- Use `checkPhase` for running unit and integration tests
- Use `installCheckPhase` for post-installation tests
- Use `passthru.tests` for running additional test suites
- Use `meta.tests` for documenting test coverage
- Use `meta.broken` to mark broken packages
- Use `meta.platforms` to specify supported platforms
- Use `meta.maintainers` to list package maintainers
- Use `meta.license` to specify package licenses
- Use `meta.homepage` to link to package documentation

## Key Rationale

Comprehensive testing ensures package reliability. Post-installation tests verify correct installation. Additional test suites (passthru.tests) catch integration issues, while proper metadata prevents installation failures and ensures appropriate package stewardship.

## Good Practice Example

A well-constructed derivation enables testing (`doCheck = true`), implements test phases, includes post-installation verification, defines additional test suites via `passthru.tests`, and populates comprehensive metadata with descriptions, licensing, platform specifications, and maintainer information.

## Anti-Pattern

Packages lacking test configuration, metadata information, and platform specifications represent inadequate quality assurance practices.
