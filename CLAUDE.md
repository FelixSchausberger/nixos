# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

This is a personal NixOS and Home Manager configuration using flakes and
flake-parts architecture. The configuration supports multiple hosts
(desktop, portable, surface, hp-probook-wsl) with modular
system and home configurations.

## AI Workflow Guidelines

### Core Workflow

Follow this process for every feature or task:

1. **Research**: Understand existing patterns and architecture
2. **Plan**: Propose approach and verify with user
3. **Implement**: Build with tests and error handling
4. **Validate**: Run formatters, linters, and tests

Start every feature with: "Let me research the codebase and create a plan before implementing."

### Problem Solving

When stuck: Stop. The simple solution is usually correct.

When uncertain about architecture or implementation: Stop and ask for guidance.
Present options clearly: "I see approach A (simple) vs B (flexible). Which do
you prefer?"

When complexity seems high: Consider whether the problem requires this
complexity or if a simpler solution exists.

Focus on maintainable solutions over clever abstractions. Readability and
simplicity are more valuable than brevity or sophistication.

### Testing Strategy

Match testing approach to code complexity:

- **Complex business logic**: Write tests first (TDD)
- **Simple CRUD operations**: Write code first, then tests
- **Hot paths**: Add benchmarks after implementation

Always validate implementation with appropriate tests.

### Security Principles

Security is fundamental to all code:

- Validate all inputs
- Use crypto/rand for randomness
- Use prepared SQL statements
- Apply principle of least privilege

### Performance Guidelines

Measure before optimizing. Never guess at performance bottlenecks.

### Progress Tracking

Use TodoWrite tool for task management to:

- Track implementation progress
- Break down complex tasks
- Maintain focus on current work
- Provide visibility to user

## Documentation Guidelines

### Single Source of Truth

Every piece of information must have exactly one authoritative source:

- Project structure and usage: README.md
- AI workflow and development principles: CLAUDE.md
- Detailed operational guides: GitHub Wiki
- Code behavior: Inline comments and type signatures

When information appears in multiple places, one source is canonical and others
reference it.

### Absolute State Descriptions

Documentation describes the current state, never relative changes:

**Incorrect:**

```nix
# Changed from bar to foo
# This used to be different
# Updated to use new format
```

**Correct:**

```nix
# Uses foo for authentication
# Configuration follows XDG Base Directory specification
```

### Professional Style

All documentation and inline comments:

- As long as necessary, as short as possible
- No emojis or decorative elements
- No business jargon or marketing language
- Technical accuracy over friendliness
- Clear and direct communication

### Inline Comments

Comments explain why, not what:

**Incorrect:**

```nix
# Set enable to true
enable = true;
```

**Correct:**

```nix
# Required for hardware video acceleration on Intel GPUs
enable = true;
```

## Design Principles

### Maintainable Solutions Over Clever Abstractions

Choose simple, readable solutions over complex, clever ones:

- Explicit configuration over magic
- Standard patterns over custom abstractions
- Boring technology over cutting-edge
- Readable code over fewer lines

When faced with complexity, ask: Does this problem require this solution, or
does a simpler approach exist?

### Output Guidelines

Avoid unnecessary output in scripts and tools:

- Successful operations should be quiet by default
- Verbose output should be opt-in through flags like `-v` or `--verbose`
- Errors must be clear and actionable, written to stderr

## Core Architecture

The configuration uses flakes and flake-parts for modular organization. Each
host combines system configuration, home manager profiles, and shared modules.

### Design Approach

- **Modularity**: Reusable modules in `modules/system/` and `modules/home/`
- **Host isolation**: Each host in `hosts/` with corresponding home profile
- **Opt-in state**: ZFS with impermanence for declarative reproducibility
- **Secret management**: sops-nix with age encryption for declarative secrets
- **Testing**: namaka snapshot tests for module and configuration validation

For detailed directory structure and module organization, see README.md
Architecture section.

## Development Workflow

### Jujutsu Workflow

The project uses Jujutsu (jj) for version control with a simple main-branch workflow:

**Daily Workflow:**

```bash
# Work directly on main branch
jj describe -m "feat: add new feature"

# Or use AI-powered commit message
jjdescribe

# Push changes to remote main branch
jj git push
```

**Creating Feature Branches (Optional):**

For experimental features that need isolation before merging to main:

```bash
jjbranch  # or jjb
# Interactive prompts:
# 1. Select type: feat, fix, chore, docs, test, refactor, perf
# 2. Enter description (lowercase, hyphens only)
# Result: Creates branch from current revision, commits with conventional format

# When ready, use jjpush to create PR back to main
jjpush
```

**Key points:**

- Work happens on `main` by default
- Feature branches (via `jjbranch`) are optional for experimental work
- Branch names follow: `type/description` (e.g., `feat/add-auto-merge`)
- Commit messages follow conventional commits: `type: description`
- Validation enforced via prek hook
- CI (Garnix + GitHub Actions) validates all changes automatically

### Conventional Commits Validation

Commit messages are validated automatically via prek hook.

**Valid format:**

```
type(scope?): description

Types: feat, fix, docs, style, refactor, perf, test, chore
```

**Examples:**

```
feat: add auto-merge workflow
fix: resolve jj bookmark creation issue
docs: update jujutsu workflow guide
feat(ci): optimize cachix push filter
```

### CI/CD Pipeline

The project uses a hybrid CI/CD approach with Garnix and GitHub Actions.

**Garnix CI (Primary Build System):**

Garnix handles all heavy build operations with centralized signing for enhanced security:
- NixOS system configurations for all hosts
- Custom package builds (lumen, vigiland, ghost, mcp-language-server, etc.)
- Namaka snapshot tests
- Multi-architecture support ready (x86_64-linux configured)

Configuration: `garnix.yaml` at repository root

Setup: Install Garnix GitHub App at https://garnix.io (one-time manual setup required)

**GitHub Actions (Validation & Security):**

GitHub Actions handles lightweight validation and security scanning:
- Security scans (Trivy vulnerability scanner, TruffleHog secret detection)
- Pre-commit hooks validation (prek)
- Fish shell syntax validation
- Flake metadata validation
- Automated dependency updates (scheduled monthly)
- Auto-merge for PRs with `auto-merge` label

Configuration: `.github/workflows/ci.yml`, `.github/workflows/auto-merge.yml`

**Binary Caches:**

Multiple caches configured with priority-based fallback in `modules/system/nix.nix`:
- cache.nixos.org (priority 1) - Official NixOS cache
- nixpkgs-schausberger.cachix.org (priority 3) - Personal cache for custom builds
- nix-community.cachix.org (priority 5) - Community packages
- cache.garnix.io (priority 7) - Garnix CI builds with centralized signing
- Project-specific caches (priority 10-25) - COSMIC, Hyprland, Helix, etc.

Garnix cache uses centralized signing, reducing cache poisoning risks compared to traditional binary caches where multiple contributors have push access.

## Development Commands

### Essential Build Commands

Use for testing configuration changes:

```bash
# Test changes without making them permanent (recommended for AI development)
sudo nixos-rebuild test --flake .

# Validate flake syntax and evaluate all configurations
nix flake check

# Enter development shell with tools available
nix develop
```

For complete build and deployment commands, see README.md Build and Deploy
section.

### Testing and Validation

Run these after making changes:

```bash
# Format Nix code
nix fmt

# Run all pre-commit hooks
prek run --all-files

# Run snapshot tests
namaka check

# Review snapshot changes after module updates
namaka review
```

Tests are in `tests/` directory:

- `tests/hosts/` - Host configuration validation
- `tests/modules/` - Module output validation
- `tests/packages/` - Package build validation

### Package Development

```bash
# Build custom package
nix build .#packagename

# Enter package development shell with dependencies
nix develop .#packagename
```

## Code Quality and Formatting

The project uses two complementary formatting systems:

- **prek** (`.pre-commit-config.yaml`) - Git commit hooks for automatic validation
- **treefmt** (`treefmt.toml`) - Manual formatting via `nix fmt`

### Prek Hooks

Prek (a drop-in replacement for pre-commit) runs automatically on git commits
with hooks configured in `.pre-commit-config.yaml`:

- **alejandra**: Nix code formatter
- **deadnix**: Dead code detection
- **statix**: Lints and suggestions for Nix code
- **flake-checker**: Flake health checks
- **markdownlint**: Markdown linting
- **prettier**: General formatting for JSON/YAML
- **ripsecrets**: Detect secrets in code
- **trim-trailing-whitespace**: Clean up whitespace
- **yamlfmt**: YAML formatter
- **taplo**: TOML formatter
- **pre-commit-hook-ensure-sops**: Ensure sops secrets are encrypted

Run hooks manually with:

```bash
# Install hooks (done automatically in dev shell)
prek install

# Run all hooks on all files
prek run --all-files

# Run hooks on staged files only
prek run

# View prek cache directory location (for debugging or cleanup)
prek cache dir
```

### Treefmt Formatters

Treefmt (`treefmt.toml`) is used by `nix fmt` for manual formatting:

- **alejandra**: Nix code formatter
- **prettier**: JSON, TOML, YAML, and YML formatting
- **markdownlint**: Markdown linting and formatting
- **trailing-whitespace-fixer**: Remove trailing whitespace

Use with `nix fmt` to format the entire repository.

## Project Structure

For detailed project architecture, module system, custom packages, and host
configurations, see README.md Architecture section.

Key paths for AI development:

- Configuration modules: `modules/system/` and `modules/home/`
- Custom packages: `pkgs/`
- Host configurations: `hosts/`
- Home profiles: `home/profiles/`
- Tests: `tests/`

## Secrets Management

Edit secrets: `sops edit secrets/secrets.yaml`

For complete secret management documentation, see README.md Wiki: Secret
Management.

## Emergency Recovery

For comprehensive emergency recovery procedures and troubleshooting, see
README.md Wiki: Emergency Recovery.

Quick emergency commands:

```bash
emergency-status                 # Check current status
sudo systemctl emergency         # Enter emergency mode
```

## Claude Code Configuration

### MCP (Model Context Protocol) Servers

The configuration includes 3 MCP servers for enhanced functionality:

1. **github** - GitHub MCP server for repository operations
2. **nix-language-server** - Nix language support via MCP
3. **nixos** - NixOS-specific MCP server (from nixpkgs, pre-built for instant startup)

Note: ccusage is used for statusline usage tracking, not as an MCP server.

**Configuration:**

- Module file: `modules/home/tui/claude-code/default.nix`
- Generated file: `/per/etc/nixos/.mcp.json` (auto-generated via `home.activation`)
- Settings: `~/.config/claude-code/settings.json`

**How it works:**

- MCP servers are configured in Home Manager modules
- `mcp-nixos` package added to `home.packages` for instant startup (no download delay)
- During activation, `.mcp.json` is created at `/per/etc/nixos/` (project root)
- Claude Code reads `.mcp.json` for project-scoped MCP servers
- File is gitignored (contains nix store paths)
- Requires rebuild to update: `sudo nixos-rebuild switch --flake .`

**Verification:**

```bash
# List configured servers
jq -r '.mcpServers | keys[]' /per/etc/nixos/.mcp.json

# Note: `claude mcp list` has a known bug and won't show project-scoped servers
# Use `claude mcp get <server-name>` to verify individual servers
```

### Claude Code Hooks

Lightweight hooks for improved AI interaction:

1. **avoid-agreement.sh** - Prevents reflexive agreement responses, encourages critical analysis
2. **prevent-rebuild.sh** - Blocks automatic system rebuild commands (critical safety feature)

### Status Line

Custom statusline showing:

- Current directory
- Git branch and status
- Nix environment detection

## Additional Features

For deployment tools, templates, and project structure details, see README.md.

## Documentation and Wiki

Detailed documentation is maintained in the GitHub Wiki. For the list of wiki
pages and quick references, see README.md Additional Documentation section.

### Updating Wiki

The wiki is a separate git repository:

```bash
# Clone wiki repository (first time only)
cd /per/repos
git clone git@github.com:FelixSchausberger/nixos.wiki.git

# Edit markdown files
cd /per/repos/nixos.wiki
# Edit .md files as needed

# Commit and push changes
git add .
git commit -m "docs: update wiki description"
git push
```

Changes are immediately visible on GitHub after pushing.

## Important Claude Code Guidelines

### CRITICAL: REBUILD PREVENTION

Claude Code is strictly prohibited from automatically running system rebuild
commands.

**PROHIBITED COMMANDS (Permanent Changes):**

- `sudo nixos-rebuild switch` (makes changes permanent)
- `nixos-rebuild switch` (makes changes permanent)
- `sudo nixos-rebuild boot` (makes changes permanent)
- `nixos-rebuild boot` (makes changes permanent)
- `nh os switch` (makes changes permanent)
- `nh os boot` (makes changes permanent)
- `deploy` (makes changes permanent)
- `sudo deploy` (makes changes permanent)
- `home-manager switch` (makes changes permanent)
- `sudo home-manager switch` (makes changes permanent)

**ALLOWED COMMANDS (Temporary Testing):**

- `sudo nixos-rebuild test` (temporary, no bootloader changes)
- `nixos-rebuild test` (temporary, no bootloader changes)
- `nh os test` (temporary, no bootloader changes)

**ENFORCEMENT MECHANISMS:**

1. **Technical Hook**: A `prevent-rebuild.sh` hook actively monitors for prohibited
   commands
2. **Configuration Block**: Claude Code settings include rebuild prevention hooks
3. **Documentation**: This CLAUDE.md file serves as the primary reference

**REQUIRED BEHAVIOR:**

- Allow safe testing with `nixos-rebuild test` commands
- Inform the user when a rebuild is necessary
- Explain what changes require rebuilding
- Suggest testing first, then permanent commands
- Wait for explicit user confirmation for permanent changes
- Never run permanent rebuild commands automatically

**PROPER RESPONSE EXAMPLE:**

```text
I've made changes to your NixOS configuration that require a system rebuild.

Changes made:
- Updated SSL certificate configuration
- Added new systemd services
- Modified environment variables

You can test these changes safely first:
  sudo nixos-rebuild test --flake .

If everything works correctly, make them permanent:
  sudo nixos-rebuild switch --flake .

Would you like me to explain what each change does before you test?
```

**TECHNICAL ENFORCEMENT:**

The system includes automated hooks that will:

- Allow safe test commands (`nixos-rebuild test`, `nh os test`)
- Block permanent commands (`nixos-rebuild switch`, `nh os switch`, `deploy`)
- Display clear guidance when violations are detected
- Enforce the policy through multiple layers (hooks + configuration + documentation)

This comprehensive approach ensures Claude can safely test changes while preventing
automatic permanent modifications to the system.
