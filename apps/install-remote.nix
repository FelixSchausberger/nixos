{pkgs}: {
  type = "app";
  program = "${pkgs.writeShellScript "install-remote" ''
        set -euo pipefail

        if [[ $# -lt 2 ]]; then
          echo "Usage: nix run .#install-remote HOSTNAME TARGET_IP" >&2
          echo "" >&2
          echo "Available hosts: desktop, surface, portable, hp-probook-vmware, m920q" >&2
          echo "" >&2
          echo "Example:" >&2
          echo "  nix run .#install-remote hp-probook-vmware 192.168.1.100" >&2
          echo "" >&2
          echo "Prerequisites:" >&2
          echo "  - Target booted with custom NixOS ISO (installer-iso-minimal)" >&2
          echo "  - SSH access to target as root (uses authorized_keys from ISO)" >&2
          echo "  - Sops key at /per/system/sops-key.txt on executing host" >&2
          echo "  - SSH keys at ~/.ssh/id_ed25519 on executing host" >&2
          echo "" >&2
          echo "The script will:" >&2
          echo "  1. Copy sops key and SSH keys to target" >&2
          echo "  2. Set up GitHub authentication" >&2
          echo "  3. Run disko partitioning" >&2
          echo "  4. Install NixOS" >&2
          echo "  5. Clone config to /per/etc/nixos" >&2
          echo "  6. Rebuild from persistent location" >&2
          exit 1
        fi

        HOSTNAME="$1"
        TARGET_IP="$2"
        SOPS_KEY="/per/system/sops-key.txt"
        REPO_URL="https://github.com/FelixSchausberger/nixos.git"
        SSH_OPTS="-o StrictHostKeyChecking=accept-new"

        if [[ ! -f "$SOPS_KEY" ]]; then
          echo "Error: Sops key not found at $SOPS_KEY" >&2
          exit 1
        fi

        echo "Decrypting GitHub token from sops secrets..."
        export SOPS_AGE_KEY_FILE="$SOPS_KEY"
        GITHUB_TOKEN=$(${pkgs.sops}/bin/sops -d secrets/secrets.yaml | ${pkgs.yq}/bin/yq -r '.github.token')

        if [[ -z "$GITHUB_TOKEN" || "$GITHUB_TOKEN" == "null" ]]; then
          echo "Error: Failed to decrypt GitHub token from secrets/secrets.yaml" >&2
          echo "Please ensure the sops key is correct and secrets.yaml contains github.token" >&2
          exit 1
        fi

        case "$HOSTNAME" in
          desktop|surface|portable|hp-probook-vmware|m920q) ;;
          *)
            echo "Error: Invalid hostname '$HOSTNAME'" >&2
            echo "Valid options: desktop, surface, portable, hp-probook-vmware, m920q" >&2
            exit 1
            ;;
        esac

        echo "Removing old SSH host key for $TARGET_IP..."
        ssh-keygen -R "$TARGET_IP" &>/dev/null || true

        echo "Testing SSH connectivity..."
        if ! ssh $SSH_OPTS -o ConnectTimeout=5 -o BatchMode=yes "root@$TARGET_IP" "echo SSH_OK" &>/dev/null; then
          echo "Error: Cannot connect to root@$TARGET_IP via SSH with keys" >&2
          echo "" >&2
          echo "Ensure:" >&2
          echo "  1. Target is booted with custom installer ISO (installer-iso-minimal)" >&2
          echo "  2. ISO was built with your SSH keys in hosts/installer/authorized_keys" >&2
          echo "  3. Network connectivity: ping $TARGET_IP" >&2
          echo "  4. Rebuild ISO if needed: nix build .#installer-iso-minimal" >&2
          exit 1
        fi
        echo "SSH connection successful"

        TMPDIR=$(mktemp -d)
        trap "rm -rf '$TMPDIR'" EXIT

        echo "Preparing installation files..."
        mkdir -p "$TMPDIR/per/system"
        cp "$SOPS_KEY" "$TMPDIR/per/system/sops-key.txt"
        chmod 400 "$TMPDIR/per/system/sops-key.txt"

        # Copy SSH keys if they exist (for sops age key derivation and GitHub auth)
        copy_ssh_keys() {
          local dest="$1"
          mkdir -p "$dest"
          cp ~/.ssh/id_ed25519 "$dest/"
          cp ~/.ssh/id_ed25519.pub "$dest/"
          chmod 700 "$dest"
          chmod 600 "$dest/id_ed25519"
          chmod 644 "$dest/id_ed25519.pub"
        }

        if [[ -f ~/.ssh/id_ed25519 ]]; then
          copy_ssh_keys "$TMPDIR/per/home/schausberger/.ssh"
          copy_ssh_keys "$TMPDIR/root/.ssh"

          mkdir -p "$TMPDIR/per/home/schausberger/.config/git"
          cat > "$TMPDIR/per/home/schausberger/.config/git/config" <<'EOF'
    [url "ssh://git@github.com/"]
      insteadOf = https://github.com/
    EOF
          chmod 644 "$TMPDIR/per/home/schausberger/.config/git/config"
        fi

        echo "Copying sops key and SSH keys to target..."
        rsync -az -e "ssh $SSH_OPTS" "$TMPDIR/" "root@$TARGET_IP:/"

        # Known_hosts needed for SSH git operations during install
        ssh $SSH_OPTS "root@$TARGET_IP" "ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null"

        # Copy local repo to temporary location (includes .git for clean flake)
        echo "Copying repository to target..."
        ssh $SSH_OPTS "root@$TARGET_IP" "rm -rf /tmp/nixos-config && mkdir -p /tmp/nixos-config"
        rsync -az --delete -e "ssh $SSH_OPTS" \
          --exclude='result*' \
          --exclude='.direnv' \
          ./ "root@$TARGET_IP:/tmp/nixos-config/"

        # Run disko partitioning (use file directly to avoid flake input fetching)
        echo "Running disko partitioning..."
        ssh $SSH_OPTS "root@$TARGET_IP" "cd /tmp/nixos-config && nix --extra-experimental-features 'nix-command flakes' run --no-update-lock-file git+ssh://git@github.com/nix-community/disko -- --mode disko ./hosts/$HOSTNAME/disko.nix"

        ssh $SSH_OPTS "root@$TARGET_IP" "git config --global --add safe.directory /tmp/nixos-config"

        # Copy sops key to persistent ZFS /per dataset (disko mounts it under /mnt)
        # Must happen after disko so /mnt/per exists
        echo "Placing sops key on persistent storage..."
        ssh $SSH_OPTS "root@$TARGET_IP" \
          "mkdir -p /mnt/per/system && chmod 700 /mnt/per/system && \
           cat > /mnt/per/system/sops-key.txt && chmod 400 /mnt/per/system/sops-key.txt" \
          < "$SOPS_KEY"

        # Activate swap partition created by disko to prevent OOM during build.
        # The live ISO boots without swap. Disko creates an 8GB swap partition
        # (partition 2: after ESP, before ZFS) with randomEncryption=true which
        # sets up dm-crypt — but we need plain swap during the install phase.
        # mkswap overwrites the dm-crypt header; NixOS will re-create it on first boot.
        echo "Activating swap partition for install phase..."
        ssh $SSH_OPTS "root@$TARGET_IP" \
          'SWAP=$(lsblk -rno NAME,PARTLABEL | awk "$2==\"swap\"{print \"/dev/\"\$1}"); [[ -z "$SWAP" ]] && SWAP=/dev/nvme0n1p2; mkswap "$SWAP" && swapon "$SWAP"'

        # Memory optimization: use existing lock file, limit parallelism, enable eval cache
        echo "Installing NixOS..."
        ssh $SSH_OPTS "root@$TARGET_IP" "cd /tmp/nixos-config && NIX_CONFIG='access-tokens = github.com=$GITHUB_TOKEN max-jobs = 1 cores = 1 eval-cache = true' nixos-install --flake .#$HOSTNAME --no-root-password --option extra-experimental-features 'nix-command flakes' --no-write-lock-file"

        # Export the ZFS pool cleanly before rebooting.
        # Without this the pool is left in an "active" state from the ISO's perspective,
        # causing the installed system to fail to import it on first boot with:
        # "cannot import rpool, last accessed by <hostname>"
        echo "Exporting ZFS pool before reboot..."
        ssh $SSH_OPTS "root@$TARGET_IP" "umount -R /mnt && zpool export rpool"

        echo "Rebooting target system..."
        ssh $SSH_OPTS "root@$TARGET_IP" "reboot" || true

        echo "Waiting for system to come back online..."
        ssh-keygen -R "$TARGET_IP" &>/dev/null || true

        for i in {1..30}; do
          if ssh -o ConnectTimeout=2 -o BatchMode=yes $SSH_OPTS "root@$TARGET_IP" "echo READY" &>/dev/null; then
            echo "System is online"
            break
          fi
          if [[ $i -eq 30 ]]; then
            echo "Warning: Timeout waiting for system to come online" >&2
            echo "Manual reboot may be needed" >&2
            exit 1
          fi
          sleep 2
        done

        echo "Cloning configuration repository to /per/etc/nixos..."
        for attempt in {1..3}; do
          if ssh $SSH_OPTS "root@$TARGET_IP" "git clone $REPO_URL /per/etc/nixos"; then
            echo "Repository cloned successfully"
            break
          fi
          [[ $attempt -eq 3 ]] && {
            echo "ERROR: Failed to clone repository after 3 attempts" >&2
            echo "" >&2
            echo "Manual steps required:" >&2
            echo "  ssh root@$TARGET_IP" >&2
            echo "  git clone $REPO_URL /per/etc/nixos" >&2
            echo "  cd /per/etc/nixos" >&2
            echo "  sudo nixos-rebuild switch --flake .#$HOSTNAME" >&2
            exit 1
          }
          echo "Attempt $attempt failed, retrying..." >&2
          sleep 2
        done

        # Fix ownership of user files in persistent storage.
        # The user may not exist until home-manager activates on the first rebuild;
        # ignore the failure and let the rebuild create the user first.
        echo "Fixing ownership of persistent user files..."
        ssh $SSH_OPTS "root@$TARGET_IP" "chown -R schausberger:schausberger /per/home/schausberger 2>/dev/null || true"

        # Rebuild from persistent location with GitHub authentication (memory-optimized)
        echo "Rebuilding from /per/etc/nixos to finalize installation..."
        if ! ssh $SSH_OPTS "root@$TARGET_IP" "cd /per/etc/nixos && NIX_CONFIG='access-tokens = github.com=$GITHUB_TOKEN max-jobs = 1 cores = 1' nixos-rebuild switch --flake .#$HOSTNAME --option extra-experimental-features 'nix-command flakes' --no-write-lock-file"; then
          echo ""
          echo "WARNING: Final rebuild failed."
          echo "The system is installed and bootable, but may need a manual rebuild."
          echo ""
          echo "After logging in as schausberger:"
          echo "  cd /per/etc/nixos"
          echo "  sudo nixos-rebuild switch --flake .#$HOSTNAME"
          echo ""
          echo "Note: The system will use sops-managed GitHub authentication after first boot."
        fi

        echo ""
        echo "Installation complete!"
        echo ""
        echo "SSH keys have been installed to /per/home/schausberger/.ssh/"
        echo "GitHub authentication configured to use SSH"
        echo ""
        echo "You can now:"
        echo "  ssh schausberger@$TARGET_IP"
        echo "  cd /per/etc/nixos && sudo nixos-rebuild switch --flake .#$HOSTNAME"
  ''}";
  meta.description = "Remote NixOS installation with sops key and repo cloning";
}
