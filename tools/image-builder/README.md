# NixOS ZFS Image Builder

Automated image generation for faster host deployment.

## Build Images

```bash
# Build installer ISO (includes ZFS tools and your flake)
nix build .#installer-iso

# Build VMDK for testing/deployment
nix build .#vmdk-portable

# Build all images
nix run .#build-all-images
```

## Deployment Scenarios

### 1. VM Testing (Recommended)

```bash
# Test in VMware/VirtualBox
nix build .#vmdk-portable
# Import result/nixos.vmdk into your VM software
```

### 2. Physical Hardware Installation

```bash
# Boot from installer ISO
nix build .#installer-iso
# Flash result/iso/nixos.iso to USB

# Or dd VMDK directly to disk (advanced)
nix build .#vmdk-portable
sudo dd if=result/nixos.vmdk of=/dev/sdX bs=1M status=progress
```

### 3. Cloud Deployment

```bash
# Convert to other formats
qemu-img convert result/nixos.vmdk -O qcow2 nixos.qcow2
qemu-img convert result/nixos.vmdk -O vdi nixos.vdi
```

## Host Profiles

Each host profile gets its own VMDK:

- `vmdk-portable`: General laptop/portable configuration
- `vmdk-surface`: Microsoft Surface specific optimizations
- `vmdk-desktop`: Desktop workstation setup
- `vmdk-server`: Server configuration

## Customization

Edit `tools/image-builder/default.nix` to:

- Add new host profiles
- Modify installer behavior
- Include additional tools
- Configure auto-installation
