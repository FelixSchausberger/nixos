# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

This is a personal NixOS and Home Manager configuration using flakes and
flake-parts architecture. The configuration supports multiple hosts
(desktop, portable, surface, pdemu1cml000312) with modular system and home
configurations.

## Core Architecture

### Flake Structure

- **Entry point**: `flake.nix` - Main flake configuration with inputs and outputs
- **Hosts**: `hosts/` - System-level configurations per machine
- **Home profiles**: `home/profiles/` - User-specific configurations per machine
- **Modules**: `modules/` - Reusable system and home manager modules
- **Packages**: `pkgs/` - Custom package definitions (basalt, lumen)
- **Tools**: `tools/` - Utility scripts and ZFS setup tools

### Key Configuration Areas

- **System modules**: `modules/system/` - Core system, hardware, fonts,
  development tools
- **Home modules**: `modules/home/` - GUI applications, TUI tools, shells,
  work configurations
- **Security**: Uses sops-nix for secrets management with age encryption
- **ZFS**: Configured with opt-in state (darling erasure) for impermanence

## Development Commands

### Building and Testing

```bash
# Build system configuration
sudo nixos-rebuild switch --flake .

# Build specific host
sudo nixos-rebuild switch --flake .#hostname

# Test configuration without switching
sudo nixos-rebuild test --flake .

# Build home manager configuration
home-manager switch --flake .

# Check flake for errors
nix flake check

# Update flake inputs
nix flake update
```

### NX Management Commands

The configuration includes custom Fish shell functions for NixOS management via the
`nx` command:

```bash
# Show all available commands
nx --help

# Edit configuration files (opens yazi file browser)
nx config

# Deploy configuration to current host (includes Home Manager)
nx deploy

# Deploy Home Manager only (standalone)
nx home

# Update flake inputs and redeploy
nx update

# Clean old generations
nx clean

# Run garbage collection
nx gc

# Run full maintenance (update + cleanup + optimize)
nx doctor

# Rollback to previous generation
nx rollback

# View system generation history
nx history
```

### Development Environment

```bash
# Enter development shell
nix develop

# Format code (uses alejandra)
nix fmt

# Run pre-commit hooks
pre-commit run --all-files
```

### Package Management

```bash
# Build custom packages
nix build .#basalt
nix build .#lumen

# Enter package development shell
nix develop .#packagename
```

## Code Quality and Formatting

The project uses pre-commit hooks with:

- **alejandra**: Nix code formatter
- **deadnix**: Dead code detection
- **flake-checker**: Flake health checks
- **markdownlint**: Markdown linting
- **nixd**: Nix language server
- **prettier**: General formatting (excludes .js, .md, .ts)

## Secrets Management

Uses sops-nix for secrets management with age encryption:

- **Single shared secrets file**: `/per/etc/nixos/secrets/secrets.yaml`
  contains all secrets including:
  - Shared: claude, github, rclone, schausberger, ssh, wifi, bitwarden
  - Host-specific (pdemu1cml000312): awscli, vpn, gitlab, magazino
- Secrets configured in `sops.secrets` in host configurations
- Age keys configured at `/per/system/sops-key.txt`
- Edit secrets: `sops edit secrets/secrets.yaml`

## Host-Specific Configurations

Each host has:

- Hardware configuration in `hosts/hostname/hardware-configuration.nix`
- Boot configuration in `hosts/hostname/boot-zfs.nix`
- System configuration in `hosts/hostname/default.nix`
- Corresponding home profile in `home/profiles/hostname/`

## Module System

### System Modules (`modules/system/`)

- **core**: Base system, security, users
- **hardware**: Audio, bluetooth, graphics
- **network**: Network configuration
- **nix**: Nix settings, substituters
- **work**: Work-specific configurations

### Home Modules (`modules/home/`)

- **gui**: Desktop applications (Firefox, Chromium, COSMIC, GNOME)
- **tui**: Terminal applications (Helix, Neovim, Git, Yazi)
- **shells**: Shell configurations (Fish, Starship, Zoxide)
- **work**: Work-specific home configurations

## Custom Packages

- **basalt**: Custom package in `pkgs/basalt/`
- **lumen**: Custom package in `pkgs/lumen/`

## Tools and Scripts

- **zfs-nixos-setup**: Rust-based ZFS setup utility in `tools/zfs-nixos-setup/`
- **scripts**: Custom scripts in `tools/scripts/`

## Username Configuration

The flake defines the username as "schausberger" in `flake.lib.user`.

## Important Claude Code Guidelines

- **Never automatically rebuild**: Claude should NEVER automatically run system
  rebuild commands (like `sudo nixos-rebuild switch` or `nx deploy`). Instead,
  Claude should inform the user when a rebuild is necessary and wait for manual
  confirmation before proceeding.
