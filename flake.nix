{
  description = "NixOS and Home-Manager flake";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://cache.garnix.io"
      "https://felixschausberger.cachix.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://pre-commit-hooks.cachix.org"
      "https://yazi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "felixschausberger.cachix.org-1:vCZvKWZ13V7CxC7HjRPqZJTwcKLJaaxYnfQsUIkDFaE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt4="
      "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
      "yazi.cachix.org-1:ot2ynJHj5l8T+FaRjblM6YV3sLzuEEr/KK10lC3aIaA="
    ];
    # Cache robustness settings
    narinfo-cache-positive-ttl = 3600; # 1 hour for R2 presigned URLs
    connect-timeout = 5; # Fast fail on connection issues
    stalled-download-timeout = 30; # Detect stalled downloads quickly

    # Determinate Nix-specific settings (ignored by standard Nix)
    # lazy-trees enables faster evaluation by only copying necessary files
    lazy-trees = true;
  };

  inputs = {
    # === CORE INPUTS (Used by all hosts) ===
    # Core Nix infrastructure (always needed)

    # Nixpkgs sources - toggle via config.nix useDeterminateNix boolean
    # Standard Nix (GitHub nixos-unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Determinate Nix (FlakeHub with semver)
    # See: https://docs.determinate.systems/flakehub/concepts/semver#nixpkgs
    nixpkgs-flakehub.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System utilities (shared by TUI and GUI)
    # Determinate Nix modules (only used when useDeterminateNix = true)
    # See: https://github.com/DeterminateSystems/determinate?tab=readme-ov-file#installing-using-our-nix-flake
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-inspect.url = "github:bluskript/nix-inspect";
    nur.url = "github:nix-community/NUR";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gitignore-nix = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    namaka = {
      url = "github:nix-community/namaka";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Editors (used by both TUI and GUI hosts)
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix.url = "github:helix-editor/helix";

    # File manager (used by both TUI and GUI)
    yazi.url = "github:sxyazi/yazi";

    # Yazi plugins
    yazi-clipboard = {
      url = "github:DreamMaoMao/clipboard.yazi";
      flake = false;
    };
    yazi-eza-preview = {
      url = "github:ahkohd/eza-preview.yazi";
      flake = false;
    };
    yazi-fg = {
      url = "github:DreamMaoMao/fg.yazi";
      flake = false;
    };
    yazi-mount = {
      url = "github:SL-RU/mount.yazi";
      flake = false;
    };
    yazi-starship = {
      url = "github:Rolv-Apneseth/starship.yazi";
      flake = false;
    };
    yazi-plugins = {
      url = "github:yazi-rs/plugins";
      flake = false;
    };

    # TUI applications (used by both profiles)
    bluetui = {
      url = "github:pythops/bluetui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
    zjstatus = {
      url = "github:dj95/zjstatus";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installation tools (useful for portable/recovery)
    nixos-wizard = {
      url = "github:km-clay/nixos-wizard";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # === GUI-SPECIFIC INPUTS (Only used by GUI hosts) ===
    # Desktop environment managers
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Desktop environments
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Window manager and system tools
    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stasis = {
      url = "github:saltnpepper97/stasis";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ala-lape = {
      url = "git+https://git.madhouse-project.org/algernon/ala-lape.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cthulock = {
      url = "github:FriederHannenheim/cthulock";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker = {
      url = "github:abenz1267/walker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wired = {
      url = "github:Toqozz/wired-notify";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GUI Applications
    firefox-nightly = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    typix.url = "github:loqusion/typix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # Themes
    arc-2-theme = {
      url = "github:YashjitPal/Arc-2.0";
      flake = false;
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    # Import profile detection utilities
    profileLib = import ./lib/profiles.nix;
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({self, ...}: {
      systems = ["x86_64-linux"];

      imports = [
        ./home/profiles
        ./hosts
      ];

      flake = {
        # Utility functions
        lib = rec {
          # Centralized defaults - single source of truth
          defaults = import ./lib/defaults.nix;
          fonts = import ./lib/fonts.nix;
          catppuccinColors = import ./modules/home/themes/catppuccin-colors.nix {inherit (inputs.nixpkgs) lib;};
          hosts = import ./lib/hosts.nix;

          # Legacy compatibility - keep existing API
          mkHost = import ./lib/mkHost.nix;
          profiles = profileLib;
          inherit (defaults.system) user;
          inherit (defaults) personalInfo;
          inherit (defaults) paths;
        };
      };

      perSystem = {pkgs, ...}: {
        # Expose nixpkgs for easier local builds (e.g., nix build .#fishPlugins.autopair)
        legacyPackages = pkgs;

        packages = {
          lumen = pkgs.callPackage ./pkgs/lumen {};

          # Shell tools
          starship-jj = pkgs.callPackage ./pkgs/starship-jj {};

          # MCP servers
          mcp-language-server = pkgs.callPackage ./pkgs/mcp-language-server {};

          # Editor with Steel plugin support
          helix-steel = pkgs.callPackage ./pkgs/helix-steel {};
          helix-steel-modules = pkgs.callPackage ./pkgs/helix-steel-modules {};
          scooter-hx = pkgs.callPackage ./pkgs/scooter-hx {};

          # Applications
          jolt = pkgs.callPackage ./pkgs/jolt {};
          openchamber = pkgs.callPackage ./pkgs/openchamber {};
          opencode-antigravity-auth = pkgs.callPackage ./pkgs/opencode-antigravity-auth {};
          quantumlauncher = pkgs.callPackage ./pkgs/quantumlauncher {};

          # Minimal installer ISO (fast rebuilds for testing)
          installer-iso-minimal = inputs.nixos-generators.nixosGenerate {
            inherit (pkgs.hostPlatform) system;
            format = "install-iso";
            modules = [
              ./hosts/installer-minimal
            ];
            specialArgs = {
              inherit inputs;
              repoConfig = import ./config.nix;
            };
          };

          # Full installer ISO (comprehensive recovery environment)
          installer-iso-full = inputs.nixos-generators.nixosGenerate {
            inherit (pkgs.hostPlatform) system;
            format = "install-iso";
            modules = [
              ./hosts/installer
            ];
            specialArgs = {
              inherit inputs;
              repoConfig = import ./config.nix;
            };
          };
        };

        # Helper apps
        apps = {
          nixos-anywhere = {
            type = "app";
            program = "${pkgs.writeShellScript "nixos-anywhere-helper" ''
              echo "Usage: nix run github:nix-community/nixos-anywhere -- --flake .#HOSTNAME root@IP"
              echo ""
              echo "Available hosts:"
              echo "  - desktop"
              echo "  - surface"
              echo "  - portable"
              echo "  - hp-probook-vmware"
              echo ""
              echo "Example:"
              echo "  nix run github:nix-community/nixos-anywhere -- \\"
              echo "    --flake .#hp-probook-vmware \\"
              echo "    root@192.168.1.100"
              echo ""
              echo "Note: Disk device is configured in hosts/HOSTNAME/disko/disko.nix"
              echo "      Default is /dev/sda - update if your system uses a different device"
              echo ""
              echo "For automated installation with sops key and repo cloning:"
              echo "  nix run .#install-vm hp-probook-vmware 192.168.1.100"
            ''}";
            meta.description = "Helper for deploying NixOS hosts with nixos-anywhere";
          };

          install-vm = {
            type = "app";
            program = "${pkgs.writeShellScript "install-vm" ''
                            set -euo pipefail

                            # Parse arguments
                            if [[ $# -lt 2 ]]; then
                              echo "Usage: nix run .#install-vm HOSTNAME TARGET_IP" >&2
                              echo "" >&2
                              echo "Available hosts: desktop, surface, portable, hp-probook-vmware" >&2
                              echo "" >&2
                              echo "Example:" >&2
                              echo "  nix run .#install-vm hp-probook-vmware 192.168.1.100" >&2
                              echo "" >&2
                              echo "Prerequisites:" >&2
                              echo "  - VM booted with custom NixOS ISO (installer-iso-minimal)" >&2
                              echo "  - SSH access to VM as root (uses authorized_keys from ISO)" >&2
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

                            # Decrypt GitHub token from sops secrets
                            echo "Decrypting GitHub token from sops secrets..."
                            if [[ ! -f "$SOPS_KEY" ]]; then
                              echo "Error: Sops key not found at $SOPS_KEY" >&2
                              exit 1
                            fi

                            export SOPS_AGE_KEY_FILE="$SOPS_KEY"
                            GITHUB_TOKEN=$(${pkgs.sops}/bin/sops -d secrets/secrets.yaml | ${pkgs.yq}/bin/yq -r '.github.token')

                            if [[ -z "$GITHUB_TOKEN" || "$GITHUB_TOKEN" == "null" ]]; then
                              echo "Error: Failed to decrypt GitHub token from secrets/secrets.yaml" >&2
                              echo "Please ensure the sops key is correct and secrets.yaml contains github.token" >&2
                              exit 1
                            fi

                            echo "GitHub token decrypted successfully"

                            # Validate hostname
                            case "$HOSTNAME" in
                              desktop|surface|portable|hp-probook-vmware) ;;
                              *)
                                echo "Error: Invalid hostname '$HOSTNAME'" >&2
                                echo "Valid options: desktop, surface, portable, hp-probook-vmware" >&2
                                exit 1
                                ;;
                            esac

                            # Check sops key exists
                            if [[ ! -f "$SOPS_KEY" ]]; then
                              echo "Error: Sops key not found at $SOPS_KEY" >&2
                              echo "" >&2
                              echo "The sops key is required to decrypt secrets during installation." >&2
                              echo "Ensure the key exists on this host before running install-vm." >&2
                              exit 1
                            fi

                            # Remove old host key (VM gets new host key each install)
                            echo "Removing old SSH host key for $TARGET_IP..."
                            ssh-keygen -R "$TARGET_IP" &>/dev/null || true

                            # Check SSH connectivity (should work with keys from custom ISO)
                            echo "Testing SSH connectivity..."
                            if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "echo SSH_OK" &>/dev/null; then
                              echo "Error: Cannot connect to root@$TARGET_IP via SSH with keys" >&2
                              echo "" >&2
                              echo "Ensure:" >&2
                              echo "  1. VM is booted with custom installer ISO (installer-iso-minimal)" >&2
                              echo "  2. ISO was built with your SSH keys in hosts/installer/authorized_keys" >&2
                              echo "  3. Network connectivity: ping $TARGET_IP" >&2
                              echo "  4. Rebuild ISO if needed: nix build .#installer-iso-minimal" >&2
                              exit 1
                            fi
                            echo "SSH connection successful"

                            # Create temporary directory for extra files
                            TMPDIR=$(mktemp -d)
                            trap "rm -rf '$TMPDIR'" EXIT

                            echo "Preparing installation files..."
                            mkdir -p "$TMPDIR/per/system"
                            cp "$SOPS_KEY" "$TMPDIR/per/system/sops-key.txt"
                            chmod 400 "$TMPDIR/per/system/sops-key.txt"

                            # Copy SSH keys if they exist (for sops age key derivation and GitHub auth)
                            if [[ -f ~/.ssh/id_ed25519 ]]; then
                              echo "Copying SSH keys for sops age key derivation and GitHub authentication..."

                              # Copy to user's persistent home directory
                              mkdir -p "$TMPDIR/per/home/schausberger/.ssh"
                              cp ~/.ssh/id_ed25519 "$TMPDIR/per/home/schausberger/.ssh/"
                              cp ~/.ssh/id_ed25519.pub "$TMPDIR/per/home/schausberger/.ssh/"
                              chmod 700 "$TMPDIR/per/home/schausberger/.ssh"
                              chmod 600 "$TMPDIR/per/home/schausberger/.ssh/id_ed25519"
                              chmod 644 "$TMPDIR/per/home/schausberger/.ssh/id_ed25519.pub"

                              # Also copy to root for initial setup
                              mkdir -p "$TMPDIR/root/.ssh"
                              cp ~/.ssh/id_ed25519 "$TMPDIR/root/.ssh/"
                              cp ~/.ssh/id_ed25519.pub "$TMPDIR/root/.ssh/"
                              chmod 600 "$TMPDIR/root/.ssh/id_ed25519"
                              chmod 644 "$TMPDIR/root/.ssh/id_ed25519.pub"

                              # Set up git config to use SSH for GitHub
                              mkdir -p "$TMPDIR/per/home/schausberger/.config/git"
                              cat > "$TMPDIR/per/home/schausberger/.config/git/config" <<'EOF'
              [url "ssh://git@github.com/"]
                insteadOf = https://github.com/
              EOF
                              chmod 644 "$TMPDIR/per/home/schausberger/.config/git/config"
                            fi

                            # Copy files to target
                            echo "Copying sops key and SSH keys to target..."
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "mkdir -p /per/system /per/home/schausberger/.ssh /per/home/schausberger/.config/git"
                            scp -o StrictHostKeyChecking=accept-new "$TMPDIR/per/system/sops-key.txt" "root@$TARGET_IP:/per/system/"
                            scp -o StrictHostKeyChecking=accept-new "$TMPDIR/per/home/schausberger/.ssh/"* "root@$TARGET_IP:/per/home/schausberger/.ssh/"
                            scp -o StrictHostKeyChecking=accept-new "$TMPDIR/per/home/schausberger/.config/git/config" "root@$TARGET_IP:/per/home/schausberger/.config/git/"
                            scp -o StrictHostKeyChecking=accept-new -r "$TMPDIR/root/.ssh" "root@$TARGET_IP:/root/"

                            # Set up SSH directory (git config already handles GitHub SSH via insteadOf)
                            echo "Setting up SSH for GitHub..."
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "mkdir -p /root/.ssh"

                            # Add GitHub to known_hosts for SSH git operations
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null"

                            # Copy local repo to temporary location (includes .git for clean flake)
                            echo "Copying repository to target..."
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "rm -rf /tmp/nixos-config && mkdir -p /tmp/nixos-config"
                            rsync -az --delete -e "ssh -o StrictHostKeyChecking=accept-new" \
                              --exclude='result*' \
                              --exclude='.direnv' \
                              ./ "root@$TARGET_IP:/tmp/nixos-config/"

                            # Run disko partitioning (use file directly to avoid flake input fetching)
                            echo "Running disko partitioning..."
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "cd /tmp/nixos-config && nix --extra-experimental-features 'nix-command flakes' run --no-update-lock-file git+ssh://git@github.com/nix-community/disko -- --mode disko ./hosts/$HOSTNAME/disko/disko.nix"

                            # Fix git ownership for nixos-install
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "git config --global --add safe.directory /tmp/nixos-config"

                            # Install NixOS with GitHub authentication via environment variable
                            # Memory optimization: use existing lock file, limit parallelism, enable eval cache
                            echo "Installing NixOS with GitHub authentication (memory-optimized)..."
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "cd /tmp/nixos-config && NIX_CONFIG='access-tokens = github.com=$GITHUB_TOKEN max-jobs = 1 cores = 1 eval-cache = true' nixos-install --flake .#$HOSTNAME --no-root-password --option extra-experimental-features 'nix-command flakes' --no-write-lock-file"

                            # Wait for reboot and remove old host key again
                            echo "Waiting for system to reboot..."
                            sleep 10
                            ssh-keygen -R "$TARGET_IP" &>/dev/null || true

                            for i in {1..30}; do
                              if timeout 5 ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "echo READY" &>/dev/null; then
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

                            # Clone repository with retries
                            echo "Cloning configuration repository to /per/etc/nixos..."
                            clone_success=false
                            for attempt in {1..3}; do
                              if ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "git clone $REPO_URL /per/etc/nixos" 2>&1; then
                                echo "Repository cloned successfully"
                                clone_success=true
                                break
                              else
                                echo "Attempt $attempt failed, retrying..." >&2
                                sleep 2
                              fi
                            done

                            if [[ "$clone_success" != true ]]; then
                              echo "ERROR: Failed to clone repository after 3 attempts" >&2
                              echo "" >&2
                              echo "Manual steps required:" >&2
                              echo "  ssh root@$TARGET_IP" >&2
                              echo "  git clone $REPO_URL /per/etc/nixos" >&2
                              echo "  cd /per/etc/nixos" >&2
                              echo "  sudo nixos-rebuild switch --flake .#$HOSTNAME" >&2
                              exit 1
                            fi

                            # Fix ownership of user files in persistent storage
                            echo "Fixing ownership of persistent user files..."
                            ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "chown -R schausberger:schausberger /per/home/schausberger"

                            # Rebuild from persistent location with GitHub authentication (memory-optimized)
                            echo "Rebuilding from /per/etc/nixos to finalize installation..."
                            if ! ssh -o StrictHostKeyChecking=accept-new "root@$TARGET_IP" "cd /per/etc/nixos && NIX_CONFIG='access-tokens = github.com=$GITHUB_TOKEN max-jobs = 1 cores = 1' nixos-rebuild switch --flake .#$HOSTNAME --option extra-experimental-features 'nix-command flakes' --no-write-lock-file"; then
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
            meta.description = "Automated VM installation with sops key and repo cloning";
          };
        };

        # Snapshot tests using namaka
        checks = inputs.namaka.lib.load {
          src = ./tests;
          inputs = {
            namaka = inputs.namaka.lib;
            flake = self;
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            actionlint # GitHub Actions linter for pre-commit hooks
            alejandra
            bashInteractive # Use interactive bash with full features
            bc # Required by calculate-coverage.sh for mathematical calculations
            deadnix
            fish
            flake-checker # Flake input health monitoring
            git
            inotify-tools # File system watching for niri-watch
            just # Task runner for development workflows
            nodePackages.prettier
            pre-commit-hook-ensure-sops
            prek
            ssh-to-age
            statix
            taplo
            inputs.namaka.packages.${pkgs.hostPlatform.system}.default # Snapshot testing
          ];

          name = "nixos-config";

          shellHook = ''
            prek install
          '';
        };

        formatter = pkgs.alejandra;
      };
    });
}
