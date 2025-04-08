# FelixSchausberger/nixos

## 🗒 About

Personal configs for Home-Manager and NixOS. Using
[flakes](https://nixos.wiki/wiki/Flakes) and
[flake-parts](https://github.com/hercules-ci/flake-parts).

## 🗃️ Contents

```lang-markdown
.
├── flake.lock
├── flake.nix
├── home
│   ├── default.nix
│   ├── private
│   │   ├── default.nix
│   │   ├── gui
│   │   │   ├── calibre.nix
│   │   │   ├── default.nix
│   │   │   ├── freecad.nix
│   │   │   ├── obsidian.nix
│   │   │   ├── oculante.nix
│   │   │   ├── prusaslicer.nix
│   │   │   ├── sioyek.nix
│   │   │   └── steam.nix
│   │   └── tui
│   │       ├── default.nix
│   │       ├── git.nix
│   │       └── typix.nix
│   ├── profiles
│   │   ├── default.nix
│   │   ├── desktop
│   │   │   └── default.nix
│   │   ├── surface
│   │   │   └── default.nix
│   │   └── thinkpad
│   │       └── default.nix
│   ├── scripts
│   │   ├── Cargo.lock
│   │   ├── Cargo.toml
│   │   ├── flake.lock
│   │   ├── flake.nix
│   │   ├── LICENSE
│   │   └── README.md
│   ├── shared
│   │   ├── default.nix
│   │   ├── gui
│   │   │   ├── chromium.nix
│   │   │   ├── cosmic
│   │   │   │   ├── cosmic-applets.nix
│   │   │   │   ├── cosmic-compositor.nix
│   │   │   │   ├── cosmic-files.nix
│   │   │   │   ├── cosmic-panels.nix
│   │   │   │   ├── cosmic-shortcuts.nix
│   │   │   │   ├── cosmic-term.nix
│   │   │   │   ├── cosmic-wallpapers.nix
│   │   │   │   └── default.nix
│   │   │   ├── default.nix
│   │   │   ├── firefox
│   │   │   │   ├── default.nix
│   │   │   │   └── tabliss.css
│   │   │   ├── gnome.nix
│   │   │   ├── mpv.nix
│   │   │   ├── planify.nix
│   │   │   ├── spicetify.nix
│   │   │   ├── vscode.nix
│   │   │   └── zen.nix
│   │   ├── shells
│   │   │   ├── default.nix
│   │   │   ├── fish.nix
│   │   │   ├── starship.nix
│   │   │   └── zoxide.nix
│   │   ├── tui
│   │   │   ├── bat.nix
│   │   │   ├── default.nix
│   │   │   ├── direnv.nix
│   │   │   ├── eza.nix
│   │   │   ├── fd.nix
│   │   │   ├── fzf.nix
│   │   │   ├── gammastep.nix
│   │   │   ├── git.nix
│   │   │   ├── helix
│   │   │   │   ├── default.nix
│   │   │   │   ├── dprint.nix
│   │   │   │   └── languages.nix
│   │   │   ├── jujutsu.nix
│   │   │   ├── neovim.nix
│   │   │   ├── nix.nix
│   │   │   ├── nixvim
│   │   │   │   ├── autocommands.nix
│   │   │   │   ├── default.nix
│   │   │   │   ├── options.nix
│   │   │   │   └── plugins
│   │   │   │       ├── default.nix
│   │   │   │       ├── lsp.nix
│   │   │   │       ├── telescope.nix
│   │   │   │       └── treesitter.nix
│   │   │   ├── rclone.nix
│   │   │   ├── rip.nix
│   │   │   ├── sops.nix
│   │   │   ├── tealdeer.nix
│   │   │   ├── thefuck.nix
│   │   │   └── yazi
│   │   │       ├── default.nix
│   │   │       ├── plugins
│   │   │       │   ├── chmod.nix
│   │   │       │   ├── clipboard.nix
│   │   │       │   ├── default.nix
│   │   │       │   ├── eza-preview.nix
│   │   │       │   ├── fg.nix
│   │   │       │   ├── git.nix
│   │   │       │   ├── mount.nix
│   │   │       │   └── starship.nix
│   │   │       └── theme
│   │   │           ├── filetype.nix
│   │   │           ├── icons.nix
│   │   │           ├── manager.nix
│   │   │           └── status.nix
│   │   └── wallpapers
│   │       ├── appa.jpg
│   │       ├── solar-system.jpg
│   │       └── the-whale.jpg
│   └── work
│       ├── default.nix
│       └── tui
│           ├── awscli.nix
│           ├── default.nix
│           └── git.nix
├── hosts
│   ├── default.nix
│   ├── desktop
│   │   ├── boot-zfs.nix
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   ├── surface
│   │   ├── boot-zfs.nix
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── thinkpad
│       ├── boot-zfs.nix
│       ├── default.nix
│       └── hardware-configuration.nix
├── pre-commit-hooks.nix
├── README.md
├── scripts.nix
├── secrets
│   └── secrets.json
└── system
    ├── core
    │   ├── default.nix
    │   ├── security
    │   │   ├── default.nix
    │   │   ├── sops.nix
    │   │   └── ssh.nix
    │   └── users.nix
    ├── default.nix
    ├── hardware
    │   ├── bluetooth.nix
    │   ├── default.nix
    │   └── graphics.nix
    ├── network.nix
    ├── nix
    │   ├── default.nix
    │   ├── nixpkgs.nix
    │   ├── pkgs
    │   │   └── lumen
    │   │       └── default.nix
    │   ├── shared
    │   │   └── substituters.nix
    │   └── work
    │       └── substituters.nix
    └── programs
        ├── private
        │   ├── cosmic.nix
        │   └── default.nix
        ├── shared
        │   ├── default.nix
        │   ├── development.nix
        │   ├── fonts.nix
        │   └── home-manager.nix
        └── work
            ├── awscli.nix
            ├── default.nix
            └── gnome.nix
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
