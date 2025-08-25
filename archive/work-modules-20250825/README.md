# Work Modules Archive - 2025-08-25

This directory contains archived work-related modules from the NixOS configuration.

## Archived Components

### Home Manager Work Modules (`home-work/`)

- `awscli.nix` - AWS CLI configuration
- `default.nix` - Main work module configuration
- `fish.nix` - Work-specific fish shell configuration
- `git.nix` - Work-specific git configuration

### System Work Modules (`system-work/`)

- `awscli.nix` - System-level AWS CLI configuration
- `default.nix` - Main system work module
- `vpn.nix` - VPN configuration

## Restoration

To restore these modules in the future:

1. Copy the desired modules back to `modules/home/work/` or `modules/system/work/`
2. Add work module imports back to the respective `default.nix` files
3. Update any work-related secrets in `secrets/secrets.yaml`

## Archive Date

Created: 2025-08-25
Reason: Transitioning to new work environment
