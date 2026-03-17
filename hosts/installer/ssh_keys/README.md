# SSH Keys for Installer ISO

**SECURITY WARNING**: This directory contains SSH private keys that will be baked into the installer ISO.

## Purpose

These SSH keys are included in the installer ISO to enable:
1. GitHub authentication during installation
2. sops secret decryption using ssh-to-age
3. Seamless install-vm workflow

## Usage

1. **Copy your SSH keys here** (before building the ISO):
   ```bash
   cp ~/.ssh/id_ed25519 hosts/installer/ssh_keys/
   cp ~/.ssh/id_ed25519.pub hosts/installer/ssh_keys/
   chmod 600 hosts/installer/ssh_keys/id_ed25519
   chmod 644 hosts/installer/ssh_keys/id_ed25519.pub
   ```

2. **Build the installer ISO**:
   ```bash
   nix build .#installer-iso-minimal
   ```

3. **The ISO will automatically**:
   - Copy SSH keys to `/per/home/schausberger/.ssh/`
   - Set correct permissions (600 for private, 644 for public)
   - Make them available for sops-nix and GitHub authentication

## Security Considerations

- ⚠️ **DO NOT commit SSH keys to git** (this directory is gitignored)
- ⚠️ **DO NOT share ISOs containing private keys**
- ⚠️ **Only use for personal/testing environments**
- ✅ For production, use install-vm script which copies keys securely over SSH

## Alternative: install-vm Script

If you prefer not to bake keys into the ISO, use the install-vm script:
```bash
nix run .#install-vm hp-probook-vmware 192.168.1.100
```

This securely copies SSH keys from your dev machine to the target over SSH.
