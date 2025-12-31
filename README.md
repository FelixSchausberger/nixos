# FelixSchausberger/nixos

[![CI Pipeline](https://github.com/FelixSchausberger/nixos/actions/workflows/ci.yml/badge.svg)](https://github.com/FelixSchausberger/nixos/actions)
![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/FelixSchausberger/c9ae337c71e6379e6725776bed1a5f96/raw/coverage.json)
![Eval Time](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/FelixSchausberger/c9ae337c71e6379e6725776bed1a5f96/raw/eval-time.json)
![Quality Gates](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/FelixSchausberger/c9ae337c71e6379e6725776bed1a5f96/raw/quality-gates.json)
![CI](https://github.com/FelixSchausberger/nixos/workflows/CI%20Pipeline/badge.svg)

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
- shells: Shell configurations (bash, fish) and shell integrations (starship, direnv, fzf, zoxide, eza, bat)
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

### Quick VM Installation with nixos-anywhere (Recommended)

For VMware/VirtualBox VMs, use nixos-anywhere instead of building a custom ISO.

#### Automated Installation (Fully Automated - Recommended)

**Using custom ISO with SSH keys pre-configured:**

1. **Build custom minimal ISO** (one-time, or when SSH keys change)

   ```bash
   nix build .#installer-iso-minimal
   # ISO will be in ./result/iso/nixos-installer-minimal.iso
   ```

2. **Boot VM with custom ISO**
   - Attach the custom ISO to your VM
   - Boot the VM
   - Get IP address: `ip addr show`
   - **No password setup needed** - SSH keys already configured!

3. **Install from your dev machine** (fully automated)
   ```bash
   nix run .#install-vm hp-probook-vmware <vm-ip-address>
   ```

This automatically:

- Connects via SSH using your pre-configured keys (no password needed)
- Copies sops key from executing host to `/per/system/sops-key.txt` on target
- Copies SSH keys for age key derivation
- Installs NixOS with disko configuration
- Clones repository to `/per/etc/nixos` on target
- Validates installation succeeded

**Prerequisites:**

- Custom ISO built with `nix build .#installer-iso-minimal`
- Sops key exists at `/per/system/sops-key.txt` on the host executing the command
- VM booted with custom ISO

**What's pre-configured in the custom ISO:**

- Your SSH public key in `/root/.ssh/authorized_keys`
- SSH server enabled and ready
- All installation tools pre-installed
- Configuration repo available at `/per/etc/nixos`

**Troubleshooting:**

- If SSH fails: Verify custom ISO was built with latest config containing your SSH key
- If sops key missing: Ensure `/per/system/sops-key.txt` exists on your dev machine
- If repo clone fails: Manually clone with `ssh root@<vm-ip> "git clone https://github.com/FelixSchausberger/nixos.git /per/etc/nixos"`

#### Alternative: Standard ISO with Manual Setup

If you prefer using a standard NixOS ISO:

1. **Download standard NixOS minimal ISO**

   ```bash
   # From nixos.org/download
   ```

2. **Boot VM and set up SSH access**

   ```bash
   # On the VM:
   passwd  # Set root password
   ip addr show  # Get IP address

   # From dev machine:
   ssh-copy-id root@<vm-ip>  # Copy SSH keys (one-time)
   ```

3. **Install from your dev machine**
   ```bash
   nix run .#install-vm hp-probook-vmware <vm-ip-address>
   ```

#### Manual Installation

For manual control or custom configurations:

1. **Download standard NixOS minimal ISO** (same as above)

2. **Boot VM with standard ISO** (same as above)

3. **Install from your dev machine**

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#hp-probook-vmware \
     root@<vm-ip-address>
   ```

   **Note**: The disk device (`/dev/sda`) is configured in the disko configuration file. If your VM uses a different disk device (like `/dev/nvme0n1`), update it in `hosts/hp-probook-vmware/disko/disko.nix`.

4. **Post-installation setup** (manual only)

   ```bash
   # Copy sops key
   scp /per/system/sops-key.txt root@<vm-ip>:/per/system/sops-key.txt

   # Clone repository
   ssh root@<vm-ip> "git clone https://github.com/FelixSchausberger/nixos.git /per/etc/nixos"
   ```

**Requirements:**

- VM must have network access
- SSH must be reachable from dev machine
- Disko configuration must exist for the host (already configured for all hosts)

See [nixos-anywhere documentation](https://nix-community.github.io/nixos-anywhere/) for advanced options.

### Custom Installer ISO (ZFS-ready)

**Note**: For simple VM installations, consider using [nixos-anywhere](#quick-vm-installation-with-nixos-anywhere-recommended) instead. Custom ISOs are best for:

- Physical hardware without network access
- Recovery scenarios
- Air-gapped installations

This repo can build a self-contained installer ISO that includes the repo checkout, ZFS tooling, and the interactive `install-nixos` helper.

Two ISO variants are available:

- **Minimal ISO** (~1.5GB): Fast rebuilds for testing - `nix build .#installer-iso-minimal`
- **Full ISO** (~4.2GB): Complete recovery environment - `nix build .#installer-iso-full`

1. **Add SSH keys for remote installs (optional)**

   ```bash
   # Create authorized_keys file (gitignored)
   cat ~/.ssh/id_ed25519.pub > hosts/installer/authorized_keys
   ```

   Multiple keys can be appended with `cat >> hosts/installer/authorized_keys`.

2. **Build the ISO**

   ```bash
   nix build .#installer-iso-minimal  # Or .#installer-iso-full
   ```

   The artifact appears in `result/iso/` (filename includes nixpkgs version).

3. **Write to USB drive**

   ```bash
   sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

   Replace `/dev/sdX` with your USB device.

4. **Boot and install**
   - The live system includes the repo at `/per/etc/nixos`
   - SSH is available if you configured keys in step 1
   - Run `install-nixos` for guided installation (supports all hosts)

See `hosts/installer/README.md` for complete installation documentation.

#### Troubleshooting VM Installation

**FlakeHub Resolution Errors:**
If you see errors like `path 'https://api.flakehub.com/...' does not exist`:

- This occurs when building from inside the installer ISO
- Solution: Use [nixos-anywhere](#quick-vm-installation-with-nixos-anywhere-recommended) from your dev machine instead
- Alternative: Follow the manual symlink workaround in the installer welcome message

**Why does deploy work locally but fail in VMs?**

- Local systems have full network stack and FlakeHub access
- Installer ISOs have limited network during early evaluation
- nixos-anywhere solves this by building on the dev machine

**Network Access:**
Ensure the VM can reach your dev machine:

```bash
# From VM: Test connectivity
ping <dev-machine-ip>

# From dev machine: Test SSH
ssh root@<vm-ip>
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

# Flake input health (flake-checker)
flake-checker                                    # Check flake.lock health
flake-checker --no-telemetry                     # Disable telemetry
flake-checker --check-outdated --check-owner     # Specific checks only

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
- Flake input health checks (advisory)
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
