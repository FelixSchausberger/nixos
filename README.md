# FelixSchausberger/nixos

[![CI Pipeline](https://github.com/FelixSchausberger/nixos/actions/workflows/ci.yml/badge.svg)](https://github.com/FelixSchausberger/nixos/actions)

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
- trotd: Top repositories of the day (https://github.com/FelixSchausberger/trotd)
- vigiland: System monitoring tool

### Host Configuration

Each host defines:
- Hardware configuration (`hardware-configuration.nix`)
- Boot configuration (`boot-zfs.nix`)
- System configuration (`default.nix`)
- Home Manager profile in `home/profiles/hostname/`

## Development Workflow

### Jujutsu Workflow (Recommended)

```bash
# Create feature branch with conventional commit format
jjbranch
# → Interactive: Select type (feat/fix/chore/docs/test/refactor/perf)
# → Enter description (e.g., "optimize-ci-pipeline")
# → Creates branch: feat/optimize-ci-pipeline
# → Commits: "feat: optimize ci pipeline"
# → Pushes to remote automatically

# Make changes (jj automatically tracks them)
# Edit files...

# Update commit description if needed
jj describe

# Push and create PR with auto-merge
jjpush
# → Pushes changes
# → Creates PR with auto-merge label
# → CI runs automatically
# → Auto-merges when all checks pass ✅

# Aliases available:
# jjb  - Shorthand for jjbranch
```

### Git Workflow (Traditional)

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
sudo nixos-rebuild test --flake .                # Temporary, no bootloader changes

# Using nh (recommended)
nh os switch                                     # Build and activate (includes Home Manager)
nh os switch --update                            # Update inputs first
nh os test                                       # Temporary testing
nh os build                                      # Build without activating

# Aliases available in shell
deploy                                           # First nh os test, then switch
update                                           # First nh update test, then switch
clean                                            # Clean old generations
history                                          # View generation history
```

### Custom Installer ISO (ZFS-ready)

This repo can build a self-contained installer ISO that already includes the repo checkout, ZFS tooling, and the interactive `install-nixos-zfs` helper.

1. **Add SSH keys for remote installs**
   ```bash
   # append any number of public keys (file is gitignored)
   install -Dm600 <(cat ~/.ssh/id_ed25519.pub) hosts/installer/authorized_keys
   ```
   Multiple keys can be appended with `cat >> hosts/installer/authorized_keys`.
2. **Build the ISO**
   ```bash
   nix build .#installer-iso
   ```
   The artifact lands in `result/iso/` (exact filename includes the nixpkgs version).
3. **Write it to a USB drive**
   ```bash
   sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```
   Replace `/dev/sdX` with your USB device. `cp` or `balu` also work if you prefer GUI tools.
4. **Boot and install**
   - The live system symlinks this repo to `/per/etc/nixos`.
   - SSH is available immediately using the keys from step 1.
   - Run `install-nixos-zfs` on the live system to launch the guided, Disko-powered installer (supports desktop/surface/portable hosts out of the box).

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

### CI/CD Pipeline

#### Garnix CI (Primary Build System)

Garnix handles all heavy build operations:
- NixOS system configurations for all hosts
- Custom package builds
- Namaka snapshot tests
- Multi-architecture support ready

Garnix uses centralized signing for enhanced security, reducing cache poisoning risks compared to traditional binary caches.

Configuration: `garnix.yaml`

Setup: Install the Garnix GitHub App at https://garnix.io

#### GitHub Actions (Validation & Security)

GitHub Actions handles quick validation and security scanning:
- Security scans (Trivy, TruffleHog)
- Pre-commit hooks validation
- Fish shell syntax validation
- Flake metadata validation
- Automated dependency updates
- Auto-merge for PRs with `auto-merge` label

Configuration: `.github/workflows/ci.yml`, `.github/workflows/auto-merge.yml`

#### Binary Caches

- **Primary**: cache.nixos.org (official NixOS cache)
- **Personal**: felixschausberger.cachix.org (custom builds, see [Cachix Setup](../../wiki/Cachix-Setup))
- **Garnix**: cache.garnix.io (shared CI builds with centralized signing)
- **Community**: nix-community.cachix.org and project-specific caches

All caches configured in `modules/system/nix.nix` with priority-based fallback.

## Additional Documentation

Detailed guides available in the [Wiki](../../wiki):

- **[Installation Guide](../../wiki/Installation)** - Disko automated installation, ZFS setup, post-installation configuration
- **[Secret Management](../../wiki/Secret-Management)** - Detailed sops-nix usage and key management
- **[Emergency Recovery](../../wiki/Emergency-Recovery)** - Complete recovery procedures and troubleshooting
- **[Cachix Setup](../../wiki/Cachix-Setup)** - Setting up personal binary cache for faster builds
- **[Contributing](../../wiki/Contributing)** - Development guidelines and contribution workflow

### Quick Reference

Installation quick start:
```bash
git clone git@github.com:FelixSchausberger/nixos.git
cd nixos
# See wiki Installation.md for detailed setup
```

Secret management:
```bash
sops edit secrets/secrets.yaml                   # Edit secrets
```

Emergency recovery:
```bash
emergency-status                                 # Check emergency status
emergency-help                                   # Display emergency guide
sudo systemctl emergency                         # Enter emergency mode
```

WSL-specific recovery (from Windows):
```powershell
wsl --exec /run/current-system/sw/bin/wsl-emergency-shell
wsl --exec /run/current-system/sw/bin/bash --noprofile --norc
```

See wiki for complete documentation.
