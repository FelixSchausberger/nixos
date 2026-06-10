{pkgs}: {
  type = "app";
  program = "${pkgs.writeShellScript "nixos-anywhere-helper" ''
    echo "Usage: nix run github:nix-community/nixos-anywhere -- --flake .#HOSTNAME root@IP"
    echo ""
    echo "Available hosts:"
    echo "  - desktop"
    echo "  - surface"
    echo "  - portable"
    echo "  - hp-probook-vmware"
    echo "  - m920q"
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
    echo "  nix run .#install-remote hp-probook-vmware 192.168.1.100"
  ''}";
  meta.description = "Helper for deploying NixOS hosts with nixos-anywhere";
}
