# FelixSchausberger/nixos

[![CI Pipeline](https://github.com/FelixSchausberger/nixos/workflows/CI%20Pipeline/badge.svg)](https://github.com/FelixSchausberger/nixos/actions)

## About

NixOS and Home Manager configuration using flakes and flake-parts architecture. Supports multiple hosts with modular system and home configurations, ZFS with opt-in state, and sops-nix secret management.

## Architecture

### Directory Structure

```
.
├── flake.nix              # Main flake configuration with inputs and outputs
├── hosts/                 # System-level configurations per machine
│   ├── desktop/
│   ├── portable/
│   ├── surface/
│   └── hp-probook-wsl/
├── home/profiles/         # User-specific configurations per machine
├── modules/               # Reusable system and home manager modules
│   ├── system/            # System-level modules
│   └── home/              # Home manager modules
├── pkgs/                  # Custom package definitions
├── tools/                 # Utility scripts, templates, and builders
├── system/                # Core system configurations (users, hardware, persistence)
├── lib/                   # Custom utility functions and host builders
├── secrets/               # Encrypted secrets managed by sops-nix
└── tests/                 # Snapshot tests using namaka
```

### Module System

System modules in `modules/system/`:
- containers: Container configuration
- development: Development tools and environment
- emergency-shell: Emergency shell system integration
- fonts: System fonts configuration
- hardware: Hardware-specific configurations
- home-manager: Home Manager integration
- maintenance: System maintenance configuration
- wm: Window manager system integration

Home modules in `modules/home/`:
- gui: Desktop applications (browsers, terminals, COSMIC)
- tui: Terminal applications (editors, file managers, git, nh)
- shells: Shell configurations (fish, bash)
- themes: Theme system with TUI/GUI separation
- wallpapers: Wallpaper configurations
- wm: Window manager configurations (COSMIC, GNOME, Hyprland)
- work: Work-specific configurations

### Custom Packages

- lumen: AI Git commit message generator
- mcp-nixos: NixOS MCP server for Claude Code
- mcp-language-server: Language server MCP integration
- vigiland: System monitoring tool

### Host Configuration

Each host defines:
- Hardware configuration (`hardware-configuration.nix`)
- Boot configuration (`boot-zfs.nix`)
- System configuration (`default.nix`)
- Home Manager profile in `home/profiles/hostname/`

## Development Workflow

```bash
# Create feature branch
git checkout -b feature/name

# Make changes and test locally
nix flake check

# Commit (prek hooks run automatically)
git add -A
git commit -m "feat: description"

# Push and create pull request
git push -u origin feature/name
gh pr create --title "Title" --body "Description"
```

## Conventions

### Commit Messages

Follow Conventional Commits specification:

- `feat:` - New feature
- `fix:` - Bug fix
- `chore:` - Maintenance tasks
- `docs:` - Documentation changes
- `refactor:` - Code restructuring without behavior changes
- `test:` - Test additions or modifications
- `ci:` - CI/CD configuration changes

Examples:
```
feat: add ZFS encryption support
fix: resolve fish shell startup loop
chore: update flake inputs
docs: improve emergency recovery guide
```

### Branch Names

- `feature/*` - New features
- `fix/*` - Bug fixes
- `chore/*` - Maintenance and refactoring
- `docs/*` - Documentation only
- `test/*` - Test improvements

Examples:
```
feature/add-hyprland-config
fix/zellij-startup-error
chore/update-dependencies
docs/improve-installation-guide
```

## Build and Deploy

### Local Build Commands

```bash
# System rebuild
sudo nixos-rebuild switch --flake .#hostname
sudo nixos-rebuild test --flake .              # Temporary, no bootloader changes

# Using nh (recommended)
nh os switch                                     # Build and activate (includes Home Manager)
nh os switch --update                            # Update inputs first
nh os test                                       # Temporary testing
nh os build                                      # Build without activating

# Aliases available in shell
deploy                                           # Equivalent to nh os switch
update                                           # Update inputs and deploy
clean                                            # Clean old generations
history                                          # View generation history
```

### Testing

```bash
# Flake validation
nix flake check

# Snapshot tests (namaka)
namaka check                                     # Run all tests
namaka review                                    # Review and update snapshots

# Pre-commit hooks (prek)
prek run --all-files                            # Run all hooks
prek run                                         # Run on staged files

# VM testing
nix run .#vm-desktop
nix run .#vm-portable
nix run .#vm-surface
nix run .#vm-hp-probook-wsl

# Local CI testing (requires Docker)
act pull_request                                 # Run full PR workflow
act pull_request --job security --dryrun        # Dry run specific job
```

### Remote Deployment

```bash
# Deploy-rs
deploy .#desktop                                 # Deploy to remote host
deploy .#portable
deploy --dry-run .#desktop                       # Preview changes
```

### CI/CD Pipeline

The GitHub Actions pipeline executes:
- Security scans (ripsecrets)
- Pre-commit hooks validation
- Flake checks
- Parallel builds for all host configurations
- VM boot tests
- Deploy-rs dry-run validation

Configuration: `.github/workflows/ci.yml`

Binary cache: `felixschausberger.cachix.org` (see [Cachix Setup](../../wiki/Cachix-Setup) for configuration)

## Additional Documentation

Detailed guides available in the [Wiki](../../wiki):

- **[Installation Guide](../../wiki/Installation)** - VMDK installation, ZFS setup, post-installation configuration
- **[Secret Management](../../wiki/Secret-Management)** - Detailed sops-nix usage and key management
- **[Emergency Recovery](../../wiki/Emergency-Recovery)** - Complete recovery procedures and troubleshooting
- **[Cachix Setup](../../wiki/Cachix-Setup)** - Setting up personal binary cache for faster builds
- **[Contributing](../../wiki/Contributing)** - Development guidelines and contribution workflow

### Quick Reference

Installation quick start:
```bash
git clone git@github.com:FelixSchausberger/nixos.git
cd nixos
nix build .#vmdk-portable                        # Build bootable VMDK
```

Secret management:
```bash
sops edit secrets/secrets.yaml                   # Edit secrets
```

Emergency recovery:
```bash
emergency-status                                 # Check emergency status
sudo systemctl emergency                         # Enter emergency mode
```

See wiki for complete documentation.
