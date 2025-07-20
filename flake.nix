{
  description = "NixOS and Home-Manager flake";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        ./home/profiles
        ./hosts
        ./pre-commit-hooks.nix
      ];

      flake = {
        # Utility functions (keep minimal)
        lib = {
          mkHost = import ./lib/mkHost.nix;
          user = "schausberger"; # Default user
          
          # Personal information variables
          personalInfo = {
            name = "Felix Schausberger";
            email = "fel.schausberger@gmail.com";
            workEmail = "schausberger@magazino.ai";
          };
          
          # Common paths
          paths = {
            nixosConfig = "/per/etc/nixos";
            obsidianVault = "/per/vault/Brain";
            homeDir = "/home/schausberger";
            repos = "/per/repos";
          };
        };
      };

      flake.packages.x86_64-linux = {
        # VM testing - run VMs with: nix run .#vm-<hostname>
        vm-desktop = inputs.self.nixosConfigurations.desktop.config.system.build.vm;
        vm-portable = inputs.self.nixosConfigurations.portable.config.system.build.vm;
        vm-surface = inputs.self.nixosConfigurations.surface.config.system.build.vm;
        vm-pdemu1cml000312 = inputs.self.nixosConfigurations.pdemu1cml000312.config.system.build.vm;
      };

      # Modern deployment with nixos-anywhere (faster, more reliable)
      # Usage: nix run .#nixos-anywhere -- --flake .#hostname root@target-ip
      flake.packages.x86_64-linux.nixos-anywhere = inputs.nixos-anywhere.packages.x86_64-linux.default;

      # Legacy deploy-rs configuration (kept for compatibility)
      flake.deploy = {
        sshUser = "schausberger";
        nodes = {
          desktop = {
            hostname = "desktop.local";
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.desktop;
            };
          };
          portable = {
            hostname = "portable.local";
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.portable;
            };
          };
          surface = {
            hostname = "surface.local";
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.surface;
            };
          };
          pdemu1cml000312 = {
            hostname = "192.168.1.100";
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.pdemu1cml000312;
            };
          };
        };
      };

      # Deploy checks
      flake.checks = inputs.deploy-rs.lib.x86_64-linux.deployChecks inputs.self.deploy;

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        packages = {
          basalt = pkgs.callPackage ./pkgs/basalt {};
          lumen = pkgs.callPackage ./pkgs/lumen {};
          vigiland = pkgs.callPackage ./pkgs/vigiland {};

          # VMDK builder for portable workstation
          vmdk-portable = pkgs.callPackage ./tools/vmdk-builder {inherit inputs;};

          # Development workflow improvements
          config-editor = pkgs.writeShellApplication {
            name = "nx-config-editor";
            runtimeInputs = with pkgs; [yazi git];
            text = ''
              set -euo pipefail
              
              cd "${inputs.self.lib.paths.nixosConfig}"
              
              echo "📝 NixOS Configuration Editor"
              echo "=============================="
              echo "Opening configuration in yazi..."
              echo "Tip: Use 'q' to quit yazi when done"
              echo ""
              
              yazi .
              
              # Check for changes
              if [[ -n "$(git status --porcelain)" ]]; then
                echo ""
                echo "📄 Changes detected:"
                git status --short | head -10
                echo ""
                
                read -p "Review changes? [y/N]: " -n 1 -r review
                echo ""
                
                if [[ $review =~ ^[Yy]$ ]]; then
                  git diff --stat
                  echo ""
                  echo "📝 Detailed diff:"
                  git diff --color=always | head -50
                  echo ""
                fi
                
                read -p "Commit and deploy changes? [y/N]: " -n 1 -r deploy
                echo ""
                
                if [[ $deploy =~ ^[Yy]$ ]]; then
                  read -p "Commit message: " -r message
                  if [[ -n "$message" ]]; then
                    git add .
                    git commit -m "$message"
                    echo ""
                    echo "🚀 Deploying configuration..."
                    sudo nixos-rebuild switch --flake .
                  else
                    echo "Empty commit message, skipping deployment."
                  fi
                else
                  echo "Changes saved but not deployed."
                  echo "Use 'nx deploy' when ready to apply changes."
                fi
              else
                echo "No changes made."
              fi
            '';
          };

          config-validator = pkgs.writeShellApplication {
            name = "nx-validate";
            runtimeInputs = with pkgs; [nix git];
            text = ''
              set -euo pipefail
              
              cd "${inputs.self.lib.paths.nixosConfig}"
              
              echo "🔍 NixOS Configuration Validator"
              echo "==============================="
              echo ""
              
              echo "📋 Step 1: Syntax check..."
              if nix flake check --no-build; then
                echo "✅ Syntax check passed"
              else
                echo "❌ Syntax check failed"
                exit 1
              fi
              echo ""
              
              echo "🏗️  Step 2: Build test (all configurations)..."
              if nix build .#nixosConfigurations.desktop.config.system.build.toplevel --no-link --quiet; then
                echo "✅ Desktop build successful"
              else
                echo "❌ Desktop build failed"
                exit 1
              fi
              
              if nix build .#nixosConfigurations.portable.config.system.build.toplevel --no-link --quiet; then
                echo "✅ Portable build successful"  
              else
                echo "❌ Portable build failed"
                exit 1
              fi
              
              echo ""
              echo "🔒 Step 3: Security check..."
              if command -v statix >/dev/null; then
                if statix check .; then
                  echo "✅ Security check passed"
                else
                  echo "⚠️  Security warnings found (non-fatal)"
                fi
              else
                echo "ℹ️  Statix not available, skipping security check"
              fi
              
              echo ""
              echo "✅ All validations completed successfully!"
              echo "🚀 Configuration ready for deployment"
            '';
          };

          system-backup = pkgs.writeShellApplication {
            name = "nx-backup";
            runtimeInputs = with pkgs; [zfs git rsync];
            text = ''
              set -euo pipefail
              
              BACKUP_DIR="/per/backups/nixos-$(date +%Y%m%d_%H%M%S)"
              
              echo "💾 NixOS System Backup"
              echo "======================"
              echo "Backup location: $BACKUP_DIR"
              echo ""
              
              mkdir -p "$BACKUP_DIR"
              
              echo "📁 Step 1: Backing up configuration..."
              cp -r "${inputs.self.lib.paths.nixosConfig}" "$BACKUP_DIR/nixos-config"
              
              echo "🔑 Step 2: Backing up secrets..."
              if [[ -d "/per/system" ]]; then
                cp -r /per/system "$BACKUP_DIR/system-keys"
                chmod -R go-rwx "$BACKUP_DIR/system-keys"
              fi
              
              echo "📋 Step 3: Saving system state..."
              {
                echo "# NixOS System Backup - $(date)"
                echo "# =============================="
                echo ""
                echo "## System Information"
                echo "Hostname: $(hostname)"
                echo "NixOS Version: $(nixos-version)"
                echo "Generation: $(sudo nix-env -p /nix/var/nix/profiles/system --list-generations | tail -1)"
                echo ""
                echo "## Hardware Information"
                lscpu | head -10
                echo ""
                lsblk -f
                echo ""
                echo "## ZFS Status"
                zpool status || echo "ZFS not available"
                echo ""
                echo "## Network Configuration"
                ip addr show | grep -E "inet|link" | head -10
              } > "$BACKUP_DIR/system-info.txt"
              
              echo "📦 Step 4: Creating archive..."
              tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
              rm -rf "$BACKUP_DIR"
              
              echo ""
              echo "✅ Backup completed successfully!"
              echo "📦 Archive: $BACKUP_DIR.tar.gz"
              echo "📏 Size: $(du -h "$BACKUP_DIR.tar.gz" | cut -f1)"
            '';
          };

          # ZFS setup tool
          zfs-nixos-setup = pkgs.rustPlatform.buildRustPackage {
            pname = "zfs-nixos-setup";
            version = "0.1.0";
            src = ./tools/zfs-nixos-setup;
            cargoLock.lockFile = ./tools/zfs-nixos-setup/Cargo.lock;
            nativeBuildInputs = with pkgs; [pkg-config];
            buildInputs = [];
          };

          # Tool creation helper
          create-tool = pkgs.writeShellApplication {
            name = "create-tool";
            runtimeInputs = with pkgs; [coreutils findutils gnused cargo];
            text = ''
              set -euo pipefail

              if [[ $# -lt 2 ]]; then
                echo "Usage: create-tool <type> <name>"
                echo "Types: rust, nix"
                echo "Example: create-tool rust my-awesome-cli"
                exit 1
              fi

              tool_type="$1"
              tool_name="$2"
              template_dir="tools/templates/$tool_type"
              target_dir="tools/$tool_name"

              if [[ ! -d "$template_dir" ]]; then
                echo "Error: Unknown tool type '$tool_type'"
                echo "Available types: rust, nix"
                exit 1
              fi

              if [[ -d "$target_dir" ]]; then
                echo "Error: Tool '$tool_name' already exists at $target_dir"
                exit 1
              fi

              echo "Creating $tool_type tool: $tool_name"
              cp -r "$template_dir" "$target_dir"

              # Update template placeholders
              case "$tool_type" in
                rust)
                  sed -i "s/my-rust-tool/$tool_name/g" "$target_dir/Cargo.toml"
                  sed -i "s/my-rust-tool/$tool_name/g" "$target_dir/flake.nix"
                  cd "$target_dir"
                  cargo generate-lockfile
                  ;;
                nix)
                  sed -i "s/my-nix-tool/$tool_name/g" "$target_dir/flake.nix"
                  sed -i "s/my-nix-tool/$tool_name/g" "$target_dir/src/main.sh"
                  sed -i "s/my-nix-function/$tool_name/g" "$target_dir/src/default.nix"
                  ;;
              esac

              echo "✅ Created $tool_type tool at $target_dir"
              echo ""
              echo "Next steps:"
              echo "1. cd $target_dir"
              echo "2. Edit the source files to implement your tool"
              echo "3. Test with: nix develop"
              echo "4. Build with: nix build"
              echo "5. Add to main flake packages section"
            '';
          };

          # Installer ISO with ZFS support
          installer-iso =
            (inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                {
                  # ZFS support in installer
                  boot.supportedFilesystems = ["zfs"];
                  boot.kernelPackages = pkgs.linuxPackages_6_6; # Use stable LTS kernel compatible with ZFS

                  # Essential recovery tools
                  environment.systemPackages = with pkgs; [
                    zfs
                    cryptsetup
                    parted
                    gparted
                    testdisk
                    ddrescue
                    git
                    vim
                    curl
                    wget
                    rsync
                  ];

                  isoImage = {
                    volumeID = "NIXOS-ZFS-INSTALLER";
                    makeEfiBootable = true;
                    makeUsbBootable = true;
                  };
                }
              ];
            }).config.system.build.isoImage;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Nix tools
            alejandra
            git

            # Documentation and formatting
            nodejs # For prettier
            nodePackages.prettier

            # Development tools
            pre-commit

            # Deployment tools
            inputs.deploy-rs.packages.${pkgs.system}.default
          ];

          name = "nixos-config";
          DIRENV_LOG_FORMAT = "";

          shellHook = ''
            ${config.pre-commit.installationScript}
            echo "Guten Morgen!"
          '';
        };

        formatter = pkgs.alejandra;
      };
    };

  inputs = {
    # Core Nix infrastructure
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System utilities
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sopswarden = {
      url = "github:pfassina/sopswarden/unstable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.sops-nix.follows = "sops-nix";
    };

    # Desktop environments
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    # Window manager and system tools
    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wayland-pipewire-idle-inhibit = {
      url = "github:rafaelrc7/wayland-pipewire-idle-inhibit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker = {
      url = "github:abenz1267/walker";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Editors
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix.url = "github:helix-editor/helix";

    # Applications
    bluetui = {
      url = "github:pythops/bluetui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-nightly = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    typix.url = "github:loqusion/typix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # File manager and plugins
    yazi.url = "github:sxyazi/yazi";

    yazi-clipboard = {
      url = "github:DreamMaoMao/clipboard.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-eza-preview = {
      url = "github:ahkohd/eza-preview.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-fg = {
      url = "github:DreamMaoMao/fg.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-mount = {
      url = "git+https://github.com/SL-RU/mount.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-starship = {
      url = "github:Rolv-Apneseth/starship.yazi";
      flake = false; # This repo doesn't contain a flake.nix
    };

    yazi-plugins = {
      url = "github:yazi-rs/plugins";
      flake = false;
    };

    # Deployment utilities
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-db = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-inspect.url = "github:bluskript/nix-inspect";
    nur.url = "github:nix-community/NUR";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local packages and tools

    # Themes
    arc-2-theme = {
      url = "github:YashjitPal/Arc-2.0";
      flake = false;
    };

    # Installation tools (optional for portable host)
    nixos-wizard = {
      url = "github:km-clay/nixos-wizard";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
