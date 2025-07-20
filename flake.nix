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
        };
      };

      flake.packages.x86_64-linux = {
        # VM testing - run VMs with: nix run .#vm-<hostname>
        vm-desktop = inputs.self.nixosConfigurations.desktop.config.system.build.vm;
        vm-portable = inputs.self.nixosConfigurations.portable.config.system.build.vm;
        vm-surface = inputs.self.nixosConfigurations.surface.config.system.build.vm;
        vm-pdemu1cml000312 = inputs.self.nixosConfigurations.pdemu1cml000312.config.system.build.vm;
      };

      # Deploy-rs configuration for remote deployments
      flake.deploy = {
        sshUser = "schausberger";
        nodes = {
          desktop = {
            hostname = "desktop.local"; # Adjust to your actual hostname/IP
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.desktop;
            };
          };
          portable = {
            hostname = "portable.local"; # Adjust to your actual hostname/IP
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.portable;
            };
          };
          surface = {
            hostname = "surface.local"; # Adjust to your actual hostname/IP
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.surface;
            };
          };
          pdemu1cml000312 = {
            hostname = "192.168.1.100"; # Adjust to your work laptop IP/hostname
            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.pdemu1cml000312;
            };
          };
        };
      };

      # Add deploy-rs checks
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

                  isoImage.volumeID = "NIXOS-ZFS-INSTALLER";
                  isoImage.makeEfiBootable = true;
                  isoImage.makeUsbBootable = true;
                }
              ];
            }).config.system.build.isoImage;

          # ZFS VMDK image for portable workstation
          # Since make-disk-image.nix doesn't support ZFS, we create a script that builds
          # a ZFS-ready VMDK using our zfs-nixos-setup tool
          vmdk-portable = pkgs.writeShellScriptBin "build-portable-vmdk" ''
            set -e

            echo "Building ZFS-based VMDK for portable workstation..."

            # Create temporary directory for image building
            TEMP_DIR=$(mktemp -d)
            trap "rm -rf $TEMP_DIR" EXIT

            # Create 1TB raw image
            IMAGE_FILE="$TEMP_DIR/portable.raw"
            ${pkgs.qemu}/bin/qemu-img create -f raw "$IMAGE_FILE" 1T

            # Set up loop device
            LOOP_DEVICE=$(sudo ${pkgs.util-linux}/bin/losetup -f --show "$IMAGE_FILE")
            trap "sudo ${pkgs.util-linux}/bin/losetup -d $LOOP_DEVICE || true; rm -rf $TEMP_DIR" EXIT

            echo "Using loop device: $LOOP_DEVICE"

            # Create partitions: boot (512MB), swap (16GB), ZFS (rest)
            sudo ${pkgs.parted}/bin/parted "$LOOP_DEVICE" --script -- \
              mklabel gpt \
              mkpart ESP fat32 1MiB 512MiB \
              set 1 boot on \
              mkpart swap linux-swap 512MiB 16896MiB \
              mkpart primary 16896MiB 100%

            # Inform kernel about partition changes
            sudo ${pkgs.util-linux}/bin/partprobe "$LOOP_DEVICE"
            sleep 2

            # Format boot and swap partitions
            sudo ${pkgs.dosfstools}/bin/mkfs.fat -F 32 -n boot "''${LOOP_DEVICE}p1"
            sudo ${pkgs.util-linux}/bin/mkswap -L swap "''${LOOP_DEVICE}p2"

            # Create ZFS pool on the third partition
            sudo ${pkgs.zfs}/bin/zpool create -f -R /mnt \
              -O canmount=off \
              -O mountpoint=none \
              -O atime=off \
              -O compression=zstd \
              -O xattr=sa \
              -O acltype=posixacl \
              rpool "''${LOOP_DEVICE}p3"

            # Create ZFS datasets
            sudo ${pkgs.zfs}/bin/zfs create -o canmount=off -o mountpoint=none rpool/eyd
            sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/ rpool/eyd/root
            sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/home rpool/eyd/home
            sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/nix rpool/eyd/nix
            sudo ${pkgs.zfs}/bin/zfs create -o canmount=noauto -o mountpoint=/per rpool/eyd/per


            # Create blank snapshot for impermanence
            sudo ${pkgs.zfs}/bin/zfs snapshot rpool/eyd/root@blank

            # Mount filesystems
            sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/root
            sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/home
            sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/nix
            sudo ${pkgs.zfs}/bin/zfs mount rpool/eyd/per

            sudo mkdir -p /mnt/boot
            sudo mount "''${LOOP_DEVICE}p1" /mnt/boot

            # Enable swap partition
            echo "Enabling swap..."
            sudo ${pkgs.util-linux}/bin/swapon "''${LOOP_DEVICE}p2"

            # Build the system configuration
            echo "Building NixOS system configuration..."
            SYSTEM_CONFIG=$(nix build --no-link --print-out-paths .#nixosConfigurations.portable.config.system.build.toplevel)

            # Install the system
            echo "Installing NixOS to ZFS..."
            sudo mkdir -p /mnt/nix/var/nix/profiles/system
            sudo cp -r "$SYSTEM_CONFIG" /mnt/nix/var/nix/profiles/system/
            sudo ln -sf /nix/var/nix/profiles/system "$SYSTEM_CONFIG"

            # Install bootloader
            sudo mkdir -p /mnt/boot/EFI/BOOT
            sudo NIXOS_INSTALL_BOOTLOADER=1 /mnt/nix/var/nix/profiles/system/bin/switch-to-configuration boot

            # Unmount filesystems
            echo "Cleaning up..."
            sudo ${pkgs.util-linux}/bin/swapoff "''${LOOP_DEVICE}p2"
            sudo umount /mnt/boot
            sudo ${pkgs.zfs}/bin/zfs umount -a
            sudo ${pkgs.zfs}/bin/zpool export rpool

            # Convert to VMDK
            OUTPUT_DIR="$PWD/result"
            mkdir -p "$OUTPUT_DIR"
            ${pkgs.qemu}/bin/qemu-img convert -f raw -O vmdk "$IMAGE_FILE" "$OUTPUT_DIR/portable-workstation.vmdk"

            echo "✅ ZFS VMDK created successfully!"
            echo "📁 Output: $OUTPUT_DIR/portable-workstation.vmdk"
            echo "💾 Layout: 512MB boot + 16GB encrypted swap + ~1TB ZFS with impermanence"
            echo "🛠️  Includes: Full workstation + recovery tools"
            echo "⚡ Best Practice: Dedicated encrypted swap for maximum performance"
          '';
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
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
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

    # Utilities
    deploy-rs = {
      url = "github:serokell/deploy-rs";
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
  };
}
