# FelixSchausberger/nixos

## 🗒 About

Personal configs for Home-Manager and NixOS. Using
[flakes](https://nixos.wiki/wiki/Flakes) and
[flake-parts](https://github.com/hercules-ci/flake-parts).

## 📦 Setup

- Install NixOS with opt-in state (darling erasure), follow:
  - [NixOS Root on ZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/index.html)
  - [NixOS installation with opt-in state (darling erasure)](https://gist.github.com/Quelklef/e5d0d9ea0c2777db45f0779b9996c94b)
- Clone this repository: `git clone git@github.com:FelixSchausberger/nixos.git`
- Create a new host in `./hosts` and `./home/profiles`.
- Move the `hardware-configuration.nix` to `./hosts/new_host` and
create a public SSH key.
- Set up secret management with [sops-nix](https://github.com/Mic92/sops-nix):
  1. Generate an SSH key pair if you don't have one:

     ```bash
     ssh-keygen -t ed25519 -C "your_email@example.com"
     ```

  2. Convert your SSH public key to age format:

     ```bash
     ssh-to-age -i ~/.ssh/id_ed25519.pub >> .sops.yaml
     ```

  3. Create an initial secrets file:

     ```bash
     # Create an empty secrets file
     touch secrets/secrets.yaml
     # Encrypt it with your age key
     sops secrets/secrets.yaml
     ```

  4. Update the secrets file with your configuration:

     ```yaml
     example_key: "example_value"
     ```

  5. Make sure your age private key is available in the environment:

     ```bash
     export SOPS_AGE_KEY=$(cat ~/.ssh/id_ed25519 | ssh-to-age)
     ```

- Rebuild the system: `sudo nixos-rebuild switch --flake .`

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
