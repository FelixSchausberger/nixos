# FelixSchausberger/nixos

## 🗒 About

Personal configs for Home-Manager and NixOS. Using
[flakes](https://nixos.wiki/wiki/Flakes) and
[flake-parts](https://github.com/hercules-ci/flake-parts).

## 🗃️ Contents

```lang-markdown
.
|-- README.md
|-- flake.lock
|-- flake.nix
|-- home
|   |-- default.nix
|   |-- gui
|   |   |-- calibre.nix
|   |   |-- chromium.nix
|   |   |-- cosmic
|   |   |   |-- cosmic-files.nix
|   |   |   |-- cosmic-term.nix
|   |   |   `-- default.nix
|   |   |-- default.nix
|   |   |-- firefox
|   |   |   |-- default.nix
|   |   |   `-- tabliss.css
|   |   |-- freecad.nix
|   |   |-- mpv.nix
|   |   |-- obsidian.nix
|   |   |-- oculante.nix
|   |   |-- planify.nix
|   |   |-- prusaslicer.nix
|   |   |-- sioyek.nix
|   |   |-- spicetify.nix
|   |   |-- steam.nix
|   |   |-- vscode.nix
|   |   `-- zen.nix
|   |-- profiles
|   |   |-- default.nix
|   |   |-- desktop
|   |   |   `-- default.nix
|   |   `-- surface
|   |       `-- default.nix
|   |-- scripts
|   |   |-- Cargo.lock
|   |   |-- Cargo.toml
|   |   |-- LICENSE
|   |   |-- README.md
|   |   |-- flake.lock
|   |   `-- flake.nix
|   |-- shells
|   |   |-- default.nix
|   |   |-- fish.nix
|   |   |-- starship.nix
|   |   `-- zoxide.nix
|   `-- tui
|       |-- bat.nix
|       |-- broot.nix
|       |-- default.nix
|       |-- direnv.nix
|       |-- eza.nix
|       |-- fd.nix
|       |-- fzf.nix
|       |-- gammastep.nix
|       |-- git.nix
|       |-- helix
|       |   |-- default.nix
|       |   `-- languages.nix
|       |-- jujutsu.nix
|       |-- nix.nix
|       |-- rclone.nix
|       |-- rip.nix
|       |-- tealdeer.nix
|       |-- thefuck.nix
|       |-- typix.nix
|       `-- yazi
|           |-- default.nix
|           |-- plugins
|           `-- theme
|-- hosts
|   |-- default.nix
|   |-- desktop
|   |   |-- boot-zfs.nix
|   |   |-- default.nix
|   |   |-- hardware-configuration.nix
|   |   `-- ssh_host_ed25519_key.pub
|   `-- surface
|       |-- boot-zfs.nix
|       |-- default.nix
|       |-- hardware-configuration.nix
|       `-- ssh_host_ed25519_key.pub
|-- pre-commit-hooks.nix
|-- scripts.nix
`-- system
    |-- core
    |   |-- default.nix
    |   |-- security
    |   |   |-- default.nix
    |   |   |-- sops.nix
    |   |   `-- ssh.nix
    |   `-- users.nix
    |-- default.nix
    |-- hardware
    |   |-- bluetooth.nix
    |   |-- default.nix
    |   `-- graphics.nix
    |-- network.nix
    |-- nix
    |   |-- default.nix
    |   |-- nixpkgs.nix
    |   |-- pkgs
    |   |   |-- lumen
    |   |   `-- mmtui
    |   |-- sources.json
    |   |-- sources.nix
    |   `-- substituters.nix
    `-- programs
        |-- cosmic.nix
        |-- default.nix
        |-- development.nix
        |-- fonts.nix
        `-- home-manager.nix
```

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
     touch secrets/secrets.json
     # Encrypt it with your age key
     sops secrets/secrets.json
     ```

  4. Update the secrets file with your configuration:

     ```json
     {
       "example_key": "example_value"
     }
     ```

  5. Make sure your age private key is available in the environment:

     ```bash
     export SOPS_AGE_KEY=$(cat ~/.ssh/id_ed25519 | ssh-to-age)
     ```

- Rebuild the system: `sudo nixos-rebuild switch --flake .`

### 🔐 Managing Secrets

- To edit secrets:

  ```bash
  sops secrets/secrets.json
  ```

- To view decrypted secrets:

  ```bash
  sops -d secrets/secrets.json
  ```
  
- To add a new key for another user:
  1. Get their SSH public key
  2. Convert it to age format: `ssh-to-age -i their_key.pub`
  3. Add the age public key to `.sops.yaml`
  4. Re-encrypt the secrets file: `sops updatekeys secrets/secrets.json`
