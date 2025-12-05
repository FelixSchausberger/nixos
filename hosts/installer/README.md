# NixOS Installer ISO

Custom NixOS installation ISO with all necessary tools and configuration pre-loaded.

## Features

- **Pre-loaded Configuration**: Full NixOS configuration available at `/per/etc/nixos`
- **SSH Access**: Root SSH access with pre-configured authorized keys
- **Installation Tools**: Unified `install-nixos` script with hardware auto-detection
- **Recovery Tools**: Complete set of recovery and diagnostic tools
- **Network Tools**: NetworkManager (nmtui) for easy network setup
- **All Filesystems**: Support for ZFS, ext4, btrfs, xfs, and NTFS

## Building the ISO

```bash
cd /per/etc/nixos
nix build .#installer-iso
```

The ISO will be available at `result/iso/nixos-minimal-*.iso` (approximately 4.2GB).

## Preparing Installation Media

### USB Drive (Linux)

```bash
# Find your USB drive (be careful to select the correct device!)
lsblk

# Write ISO to USB (replace /dev/sdX with your USB device)
sudo dd if=result/iso/nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### USB Drive (Windows)

Use tools like:
- Rufus: https://rufus.ie/
- balenaEtcher: https://www.balena.io/etcher/

### VMware

Mount the ISO directly in VMware Workstation Pro:
1. Create new VM
2. Choose "Installer disc image file (iso)"
3. Browse to the ISO file
4. Ensure Firmware Type is set to **UEFI** (not BIOS)

## Booting the Installer

1. **Boot from USB/ISO**
2. **Wait for boot** - You'll see the NixOS Installation Environment welcome screen
3. **Login as root** (no password required)

## Network Setup

### Wired Connection
Wired connections should work automatically via DHCP.

### WiFi Setup
```bash
# Use NetworkManager TUI
nmtui

# Or command line
nmcli device wifi list
nmcli device wifi connect "SSID" password "PASSWORD"
```

## SSH Access (Optional)

If you configured SSH keys in `hosts/installer/authorized_keys`:

```bash
# Find the installer's IP address
ip addr show

# From another machine
ssh root@<installer-ip>
```

## Installation Process

### Quick Installation (Recommended)

The interactive installer auto-detects your hardware:

```bash
install-nixos
```

Follow the prompts to:
1. Select target disk
2. Choose host configuration
3. Confirm installation

### Manual Installation

Specify everything via command line:

```bash
# List available disks
lsblk

# Install with specific options
install-nixos --host hp-probook-vmware --disk /dev/sda --yes

# Available hosts:
#   desktop           - Desktop PC with AMD RX 6700XT
#   surface           - Surface tablet/laptop
#   portable          - Portable/recovery with ZFS
#   hp-probook-vmware - VMware VM
```

### Advanced: Custom Disko Configuration

For advanced users who need custom partitioning:

```bash
# Edit disko configuration
cd /per/etc/nixos
nano hosts/<hostname>/disko/disko.nix

# Run disko-install manually
nix run 'github:nix-community/disko#disko-install' -- \
  --flake ".#<hostname>" \
  --disk main /dev/sda
```

## What Gets Installed

The `install-nixos` script:
1. **Partitions** the disk using the disko configuration
2. **Formats** filesystems (ZFS/ext4/btrfs depending on host)
3. **Mounts** all filesystems at `/mnt`
4. **Installs** NixOS from the flake configuration
5. **Configures** bootloader (systemd-boot with UEFI)

## Post-Installation

After installation completes:

1. **Reboot**:
   ```bash
   reboot
   ```

2. **Remove installation media** when prompted

3. **First boot setup**:
   ```bash
   # Set user password
   passwd schausberger

   # Configure secrets (if using sops)
   # See Wiki: Secret Management
   ```

## Troubleshooting

### Installation Fails

Check the disko configuration:
```bash
cat /per/etc/nixos/hosts/<hostname>/disko/disko.nix
```

Ensure disk ID is correct (change `by-id/changeme` to actual disk ID).

### Network Issues

```bash
# Check network interfaces
ip link

# Restart NetworkManager
systemctl restart NetworkManager

# Manual DHCP
dhcpcd <interface>
```

### VMware: BIOS vs UEFI

If installation fails in VMware, ensure VM firmware is set to **UEFI**:
- VM Settings → Options → Boot Options → Firmware Type → UEFI

### Disk Not Found

```bash
# List all disks
lsblk -o NAME,SIZE,MODEL,TYPE

# List by-id paths
ls -l /dev/disk/by-id/
```

## Available Commands

The installer includes these helper scripts:

- `install-nixos` - Unified installation script (interactive/CLI)
- `nixos-install-info` - Show installation documentation
- `nixos-recover` - Auto-detect and mount existing NixOS installations

## Documentation

Full documentation available:
- Installation Guide: https://github.com/FelixSchausberger/nixos/wiki/Installation
- Secret Management: https://github.com/FelixSchausberger/nixos/wiki/Secret-Management
- Emergency Recovery: https://github.com/FelixSchausberger/nixos/wiki/Emergency-Recovery

## Adding SSH Keys

To enable SSH access in the installer, create an authorized_keys file:

```bash
# On your development machine
cat ~/.ssh/id_ed25519.pub > /per/etc/nixos/hosts/installer/authorized_keys

# Rebuild the ISO
nix build .#installer-iso
```

**Note**: The `authorized_keys` file is gitignored for security. Each user must create their own before building the ISO.

## Customization

The installer configuration is in `hosts/installer/default.nix`. You can:

- Add additional packages to `environment.systemPackages`
- Configure WiFi credentials (via sops secrets)
- Modify the welcome banner in `installerWelcome` activation script
- Customize ISO name via `image.fileName`

After making changes, rebuild:
```bash
nix build .#installer-iso
```
