# Add this to your main flake.nix perSystem.packages section
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (inputs) nixpkgs;
in {
  # Installation ISO with ZFS support
  installer-iso = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ./tools/image-builder
      {
        # Customize for your needs
        isoImage = {
          volumeID = "NIXOS-ZFS-INSTALLER";
          makeEfiBootable = true;
          makeUsbBootable = true;
        };
      }
    ];
  };

  # VMDK images for each host profile
  vmdk-portable = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
    inherit pkgs lib;
    inherit
      (nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/portable
          {
            # Pre-configured for VMDK deployment
            boot.loader.grub.device = "/dev/vda";
            fileSystems."/".device = "/dev/disk/by-label/nixos";
          }
        ];
      })
      config
      ;
    format = "vmdk";
    diskSize = 32768; # 32GB
  };

  vmdk-surface = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
    inherit pkgs lib;
    inherit
      (nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [./hosts/surface];
      })
      config
      ;
    format = "vmdk";
    diskSize = 32768;
  };

  # Quick build script
  build-all-images = pkgs.writeShellScriptBin "build-all-images" ''
    echo "Building installer ISO..."
    nix build .#installer-iso

    echo "Building VMDK images..."
    nix build .#vmdk-portable
    nix build .#vmdk-surface

    echo "Images ready in result/"
    ls -la result*/
  '';
}
