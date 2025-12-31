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

All documentation, inline comments, and code artifacts:

- As long as necessary, as short as possible
- No emojis or decorative elements in code, comments, or documentation files
- Claude may use emojis in conversational replies to the user
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

**Design Approach:**
- **Modularity**: Reusable modules in `modules/system/` and `modules/home/`
- **Host isolation**: Each host in `hosts/` with corresponding home profile
- **Opt-in state**: ZFS with impermanence for declarative reproducibility
- **Secret management**: sops-nix with age encryption for declarative secrets
- **Testing**: namaka snapshot tests for module and configuration validation

For complete details, see [README.md Architecture](README.md#architecture):
- Directory structure and file organization
- Module system details (system and home modules)
- Custom packages
- Host configuration patterns

## Development Workflow

### Version Control Strategy

The project uses Jujutsu (jj) for version control with a main-branch workflow.

**Key Principles:**
- Work happens on `main` by default for straightforward changes
- Feature branches (via `jjbranch` helper) are optional for experimental work
- Commit messages follow conventional commits format
- Validation enforced via prek hook
- CI validates all changes automatically

For complete workflow details, see [README.md Development Workflow](README.md#development-workflow):
- Jujutsu workflow (jjbranch, jjdescribe, jjpush helpers)
- Traditional Git workflow alternative
- Commit message conventions and validation
- Branch naming patterns

### CI/CD Strategy

The project uses hybrid CI/CD with Garnix (primary builds) and GitHub Actions (validation/security).

For complete CI/CD details, see [README.md Build and Deploy](README.md#build-and-deploy) → CI/CD Pipeline section:
- Garnix CI configuration and build scope
- GitHub Actions workflows
- Binary cache setup and priorities
- Auto-merge configuration

## Development Commands

### Essential Build Commands

**For AI-assisted development, prefer safe testing:**

```bash
# Test changes without making them permanent (RECOMMENDED)
sudo nixos-rebuild test --flake .

# Validate flake syntax and evaluate all configurations
nix flake check
```

For complete build commands, deployment options, and remote deployment, see [README.md Build and Deploy](README.md#build-and-deploy).

### Just Task Runner

The project includes a justfile for common development workflows, especially useful for rapid Niri iteration.

**Quick reference:**

```bash
just                    # List all available recipes
just niri-validate      # Build and validate Niri config (fast, no system rebuild)
just niri-reload        # Build, validate, and hot-reload Niri config
just niri-watch         # Watch for changes and auto-validate
just fmt                # Format Nix files
just check              # Run all pre-commit hooks
just test               # Run snapshot tests
just validate           # Full validation: format, hooks, and tests
just system-test        # Test system changes (nixos-rebuild test)
```

**Development shell:**

All just recipes require the development shell:

```bash
nix develop             # Enter dev shell
just niri-validate      # Run recipe in dev shell

# Or run directly
nix develop -c just niri-validate
```

The dev shell includes just, inotify-tools, and all development dependencies.

**Niri hot-reload workflow:**

When iterating on Niri configuration:

1. Edit Niri config in `modules/home/wm/niri/`
2. Run `just niri-validate` to check syntax (seconds, not minutes)
3. Run `just niri-reload` to apply changes to running Niri instance
4. Or use `just niri-watch` for automatic validation on file changes

This workflow avoids full system rebuilds during Niri development.

### Quality Monitoring and Metrics

The project includes comprehensive quality monitoring to ensure high code quality and prevent regressions.

**Quality metrics tracked:**
- Test coverage (critical paths, hosts, modules)
- Dead code detection (unused bindings and modules)
- Performance metrics (evaluation time, closure sizes)
- Security vulnerabilities
- Code quality issues (linting, formatting)

**Quick commands:**

```bash
# Run all quality checks
just quality-check

# Individual checks
just coverage           # Calculate test coverage
just check-unused       # Detect unused modules
just profile-eval       # Profile evaluation time
just check-closures     # Check all closure sizes
just dashboard          # Generate quality dashboard
```

**Quality gates in CI:**

Every commit and pull request must pass:
- ✅ No dead code (deadnix)
- ✅ No unused modules
- ✅ 100% critical path coverage (boot, networking, users, security, systemd)
- ✅ Evaluation time <10s
- ✅ Closure size within limits

CI fails automatically if any gate fails, preventing quality regressions.

**Viewing metrics:**

1. **Quality Dashboard**: `docs/QUALITY_DASHBOARD.md` (auto-generated)
2. **GitHub Pages**: `https://USERNAME.github.io/nixos/` (live dashboard)
3. **CI Artifacts**: Download from GitHub Actions workflow runs
4. **Local metrics**: `.quality-metrics/` directory

**Interpreting results:**

- **Coverage percentage**: Higher is better, target 100% for critical paths
- **Evaluation time**: Lower is better, target <10s for fast iteration
- **Closure sizes**: Smaller is better, indicates leaner system
- **Dead code/unused modules**: Should always be 0

**Fixing quality issues:**

```bash
# Fix formatting and dead code automatically
deadnix --edit .
statix fix .
alejandra .

# Find and remove unused modules
just check-unused --verbose
# Then manually remove the reported modules

# Improve coverage
# Add tests in tests/coverage/ or extend existing tests

# Optimize performance
just profile-eval --host desktop
# Review slow modules in output
```

**Quality monitoring setup:**

For new repositories or after cloning:

1. Run initial quality check: `just quality-check`
2. Fix any issues found
3. Establish baselines: `.quality-metrics/` will be created
4. CI will track deltas from baselines

**Dynamic badges** (optional):

Set up auto-updating badges in README showing coverage, performance, and quality gates status.
See `docs/BADGES_SETUP.md` for complete setup instructions.

### VM Installation with nixos-anywhere

For VM installations (VMware, VirtualBox, Proxmox), use nixos-anywhere:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#hostname \
  root@<vm-ip-address>
```

This is the recommended approach because:
- Builds on dev machine (no FlakeHub resolution issues)
- Uses existing disko configurations
- Simpler than custom ISO workflow
- Community-maintained standard

Custom ISOs are still useful for:
- Physical hardware installations
- Recovery scenarios
- Air-gapped environments

### Testing and Validation

**Post-change validation workflow:**

```bash
nix fmt                    # Format Nix code
prek run --all-files      # Run all pre-commit hooks
namaka check              # Run snapshot tests
namaka review             # Review snapshot changes after module updates
```

Tests are organized in `tests/` directory (hosts, modules, packages).

For complete testing documentation including VM testing and local CI, see [README.md Testing](README.md#testing).

## Modern CLI Tools

This system uses modern CLI replacements for standard Unix tools. Claude Code's built-in tools already leverage these where appropriate.

### Tool Awareness

**Search and navigation:**
- `rg` (ripgrep): Claude's Grep tool uses this internally
- `fd`: Fast file finding; use via Bash for complex patterns
- `fzf`: Fuzzy finder; use via Bash for interactive selection
- `bat`: Syntax-highlighted cat; use via Bash when highlighting aids understanding

**File operations:**
- `eza`: Modern ls with git integration; use via Bash for detailed listings
- `yazi`: Terminal file manager; use via Bash or `Alt+y` in Zellij

**Development:**
- `hx` (Helix): Primary editor (Colemak-DH keybindings, Steel plugins)
- `jj` (Jujutsu): Primary VCS (helpers: jjbranch, jjdescribe, jjpush)

### Tool Selection

**Prefer built-in tools:**
- Use Grep tool for content search (already uses ripgrep)
- Use Glob tool for file pattern matching
- Use Read tool for file contents

**Use Bash when:**
- Built-in tools are insufficient for the task
- Modern tool features provide significant value (syntax highlighting, interactive selection, git integration)
- Complex search/find patterns require custom flags

Complete tool documentation: `modules/home/shells/` and `modules/home/tui/`

## Code Quality and Formatting

The project uses two complementary formatting systems:

- **prek** (`.pre-commit-config.yaml`) - Git commit hooks for automatic validation
- **treefmt** (`treefmt.toml`) - Manual formatting via `nix fmt`

**Key formatters and linters:**
- alejandra (Nix formatter)
- deadnix, statix (Nix linting)
- markdownlint, prettier (documentation)
- ripsecrets (secret detection)
- pre-commit-hook-ensure-sops (sops validation)

**Essential commands:**
```bash
prek run --all-files      # Run all hooks manually
nix fmt                   # Format entire repository
```

Hooks run automatically on git commits. Configuration in `.pre-commit-config.yaml` and `treefmt.toml`.

## Project Structure

**Key paths for AI development:**
- `modules/system/` and `modules/home/` - Configuration modules
- `pkgs/` - Custom packages
- `hosts/` - Host configurations
- `home/profiles/` - Home profiles
- `tests/` - Tests (hosts, modules, packages)

For complete project structure, see [README.md Architecture](README.md#architecture).

## Secrets Management

**Quick command:**
```bash
sops edit secrets/secrets.yaml   # Edit secrets
```

For complete documentation, see [README.md Additional Documentation](README.md#additional-documentation) → Wiki: Secret Management.

## Emergency Recovery

**Quick commands:**
```bash
emergency-status                 # Check current status
sudo systemctl emergency         # Enter emergency mode
```

For comprehensive procedures, see [README.md Additional Documentation](README.md#additional-documentation) → Wiki: Emergency Recovery.

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

### Plugins

The configuration enables 9 official Claude Code plugins declaratively:

**Development & Git:**
- `commit-commands` - Git commit workflows (/commit, /commit-push-pr)
- `feature-dev` - Guided feature development with architecture focus
- `github` - GitHub repository operations

**Code Quality:**
- `hookify` - Create hooks to prevent unwanted behaviors
- `security-guidance` - Security best practices and vulnerability detection

**Language Support (LSP):**
- `lua-lsp` - Lua language server integration
- `rust-analyzer-lsp` - Rust language server integration

**Specialized:**
- `frontend-design` - Production-grade frontend interfaces
- `serena` - AI assistant capabilities

**Configuration:**

Plugins are enabled in `settings.json` via `enabledPlugins`:

```nix
enabledPlugins = {
  "plugin-name@claude-plugins-official" = true;
};
```

Plugins are installed automatically by Claude Code from the official marketplace.

### LSP Servers

LSP servers are managed through system packages and discovered via PATH:

**Configured LSP servers:**
- `nixd` - Nix language server (for semantic Nix operations, installed via home.packages)
- `rust-analyzer` - Rust language server (provided by rustup when Rust development is enabled)

LSP plugins (lua-lsp, rust-analyzer-lsp) require the corresponding LSP server
to be available in PATH. The rust-analyzer-lsp plugin uses the rust-analyzer
binary provided by rustup.

### MCP vs Plugins vs LSP

**When to use each:**

| Mechanism | Use Case | Examples | Configuration |
|-----------|----------|----------|---------------|
| **MCP Servers** | External tool integration, data sources | GitHub API, NixOS search, Language servers | `.mcp.json` + packages |
| **Plugins** | Reusable commands/workflows, team sharing | Commit workflows, feature dev, security | `enabledPlugins` in settings.json |
| **LSP (via plugins)** | Language-specific code intelligence | Go-to-definition, hover, diagnostics | Plugin + system package |

**MCP Servers** provide external capabilities (APIs, databases, language servers).
**Plugins** provide reusable commands, workflows, and automation.
**LSP plugins** connect Claude Code to language servers for code intelligence.

All three can coexist and complement each other.

### Claude Code Hooks

Lightweight hooks for improved AI interaction:

1. **avoid-agreement.sh** - Prevents reflexive agreement responses, encourages critical analysis
2. **prevent-rebuild.sh** - Blocks automatic system rebuild commands (critical safety feature)

### Status Line

Custom statusline showing:

- Current directory
- Git branch and status
- Nix environment detection

## Documentation and Wiki

Detailed documentation is maintained in the GitHub Wiki.

For wiki pages and quick references, see [README.md Additional Documentation](README.md#additional-documentation).

**Updating Wiki:**

The wiki is a separate git repository at `/per/repos/nixos.wiki`.

```bash
cd /per/repos/nixos.wiki        # Navigate to wiki repo
# Edit .md files as needed
git add . && git commit -m "docs: update description" && git push
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
