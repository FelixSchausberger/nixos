# FelixSchausberger/nixos

## 🗒 About

Personal configs for Home-Manager and NixOS. Using
[flakes](https://nixos.wiki/wiki/Flakes) and
[flake-parts](https://github.com/hercules-ci/flake-parts).

## 📦 Setup

### 🚀 **Method 1: VMDK Image Installation (Recommended)**

The fastest and most reliable way to install NixOS with this configuration:

#### **Step 1: Build Installation Images**

```bash
# Clone this repository
git clone git@github.com:FelixSchausberger/nixos.git
cd nixos

# Build recovery system VMDK (8GB, bootable)
nix build .#vmdk-portable

# Build installer ISO (optional, for live environment)
nix build .#installer-iso
```

#### **Step 2: Install to Target Disk**

```bash
# Convert VMDK to raw image and write to target disk
# ⚠️  WARNING: This will erase all data on target disk
qemu-img convert -f vmdk -O raw result/nixos.vmdk /tmp/nixos.raw
sudo dd if=/tmp/nixos.raw of=/dev/sdX bs=1M status=progress

# Set boot flag and install bootloader
sudo parted /dev/sdX set 1 boot on
sudo mount /dev/sdX1 /mnt
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt /nix/store/*/bin/grub-install --target=i386-pc /dev/sdX
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt
```

#### **Step 3: Boot and Configure**

1. **Boot from target disk**
2. **Login as root** (no password initially)
3. **Set up your system**:

   ```bash
   # Set root password
   passwd

   # Create your user
   useradd -m -G wheel schausberger
   passwd schausberger

   # Configure system (copy your flake configuration)
   # The recovery system includes tools to detect and mount other NixOS installations
   ```

### 🛠 **Method 2: Manual ZFS Installation (Legacy)**

For custom installations or when you need ZFS with encryption:

- Follow the ZFS installation guides:
  - [NixOS Root on ZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/index.html)
  - [NixOS installation with opt-in state (darling erasure)](https://gist.github.com/Quelklef/e5d0d9ea0c2777db45f0779b9996c94b)
- Or use the legacy tool: `tools/archive/zfs-nixos-setup-legacy/`

### 🔧 **Post-Installation Setup**

After installation with either method:

1. **Clone this repository**: `git clone git@github.com:FelixSchausberger/nixos.git`
2. **Create a new host** in `./hosts` and `./home/profiles`
3. **Move `hardware-configuration.nix`** to `./hosts/new_host`
4. **Set up secret management** with [sops-nix](https://github.com/Mic92/sops-nix):

   ```bash
   # Generate SSH key
   ssh-keygen -t ed25519 -C "your_email@example.com"

   # Convert to age format
   ssh-to-age -i ~/.ssh/id_ed25519.pub >> .sops.yaml

   # Create secrets file
   touch secrets/secrets.yaml
   sops secrets/secrets.yaml

   # Export age key
   export SOPS_AGE_KEY=$(cat ~/.ssh/id_ed25519 | ssh-to-age)
   ```

5. **Rebuild the system**: `sudo nixos-rebuild switch --flake .`

## 🚀 Deployment

### Local Deployment

```bash
# Deploy current host locally (via nx commands)
nx deploy

# Update and deploy
nx update

# Direct nixos-rebuild
sudo nixos-rebuild switch --flake .#$(hostname)
```

### Remote Deployment

```bash
# Deploy to current host via deploy-rs (SSH)
nx deploy remote

# Deploy to specific host
nx deploy remote desktop
nx deploy remote portable
nx deploy remote surface

# Dry-run to check changes
nx deploy remote --dry

# Direct deploy-rs usage
deploy .#desktop
deploy --dry-run .#portable
```

### VM Testing

```bash
# Test configurations locally before deployment
nix run .#vm-desktop
nix run .#vm-portable
nix run .#vm-surface
nix run .#vm-pdemu1cml000312
```

### CI/CD Pipeline

The GitLab CI pipeline automatically:

- ✅ **Checks**: Security scans, pre-commit hooks, flake validation
- 🏗️ **Builds**: All host configurations + VMs in parallel
- 🧪 **Tests**: VM boot tests, deploy-rs dry-runs
- 🚀 **Deploys**: Manual deployment to hosts via GitLab UI

**Setup for remote deployment:**

1. Update hostnames/IPs in `flake.nix` deploy configuration
2. Set up SSH keys: `ssh-copy-id schausberger@hostname.local`
3. Configure passwordless sudo on target hosts
4. Test: `nx deploy remote --dry`

### 🔧 **Recovery System Features**

The portable recovery system includes comprehensive recovery tools:

#### **Available Tools**

- `nixos-recover` - Auto-detects and mounts NixOS installations
- `create-nixos-installer` - Builds new VMDK images from the recovery system
- `gparted` - Disk partitioning GUI
- `testdisk` - Data recovery from damaged disks
- `cryptsetup` - LUKS encryption management
- Complete ZFS tools for pool management
- Network tools (NetworkManager, SSH, etc.)

#### **Recovery Workflow**

```bash
# Boot recovery system and login as root
# Detect and mount existing NixOS installation
nixos-recover

# Enter the mounted system for repair
nixos-enter

# Or create new installation images
create-nixos-installer
```

#### **System Architecture**

- **Root filesystem**: tmpfs (runs in RAM, clean each boot)
- **Purpose**: Recover ZFS systems on other drives
- **Network**: WiFi and Ethernet support via NetworkManager
- **Users**: `root` (for system recovery) and `rescue` (for safe operations)

### 🔐 Managing Secrets

- To edit secrets:

  ```bash
  sops edit secrets/secrets.yaml
  ```

- To add a new key for another user:
  1. Get their SSH public key
  2. Convert it to age format: `ssh-to-age -i their_key.pub`
  3. Add the age public key to `.sops.yaml`
  4. Re-encrypt the secrets file: `sops updatekeys secrets/secrets.yaml`
