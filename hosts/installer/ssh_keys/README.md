# SSH Keys for Installer ISO

This directory holds no key material: nothing in the ISO build reads it, and
no private key may enter the repository or the image.

## Where key handling lives

- ISO SSH access uses public keys from `hosts/installer/authorized_keys`.
- Each installed host decrypts sops secrets with its SSH host key, registered
  as a recipient in `.sops.yaml` by `nix run .#new-host-keys`.
- `nix run .#install-remote` fetches the host key from the Bitwarden vault
  item `host/<hostname>` and plants it at `/mnt/per/etc/ssh/` after
  partitioning, before `nixos-install` runs.
- On first boot sops-nix plants the user key `~/.ssh/id_ed25519` (encrypted
  in `secrets/secrets.yaml`, decrypted with the host key); Home Manager's
  sops module then decrypts the remaining user secrets with that key.

The installation procedure, including regenerating installer SSH access, is
documented in `hosts/installer/README.md`.
